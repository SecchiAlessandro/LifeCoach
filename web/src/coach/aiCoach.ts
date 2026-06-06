// On-device AI coach — the web analog of Coach/OnDeviceCoach.swift. Runs an
// open-source LLM (Qwen2.5-0.5B-Instruct) entirely in the browser via WebLLM +
// WebGPU. Like iOS: it ONLY enhances the coaching prose; scoring stays
// deterministic and the rule-based coach is always the fallback.

import type { InitProgressReport, MLCEngineInterface } from "@mlc-ai/web-llm";
import {
  balance as computeBalance,
  bottleneck as computeBottleneck,
  ENERGY_TITLE,
  type CheckInQuestion,
  type Energy,
  type EnergyScores,
} from "../models/energy";
import type { UserProfile } from "../store/db";
import { coachingFor, type CoachResult } from "./ruleBasedCoach";

// Preferred model ids, most-preferred first. Resolved against the installed
// prebuilt config so we stay resilient to version/id changes. The first two are
// the chosen Qwen2.5-0.5B (f16 quant, then an f32 quant for GPUs without
// shader-f16); the rest are small fallbacks.
const PREFERRED_MODELS = [
  "Qwen2.5-0.5B-Instruct-q4f16_1-MLC",
  "Qwen2.5-0.5B-Instruct-q4f32_1-MLC",
  "Qwen3-0.6B-q4f16_1-MLC",
  "SmolLM2-360M-Instruct-q4f16_1-MLC",
];

export const AI_MODEL_LABEL = "Qwen2.5 0.5B Instruct";
export const AI_MODEL_LICENSE = "Apache-2.0";
export const AI_MODEL_APPROX_MB = 350;

export type CoachStatus =
  | { phase: "idle" }
  | { phase: "loading"; progress: number; text: string }
  | { phase: "ready" }
  | { phase: "error"; message: string };

type Listener = (status: CoachStatus) => void;

class AICoachManager {
  private engine: MLCEngineInterface | null = null;
  private loadPromise: Promise<MLCEngineInterface> | null = null;
  private listeners = new Set<Listener>();
  status: CoachStatus = { phase: "idle" };

  /** WebGPU is required; gracefully report when it's missing (e.g. Firefox). */
  get supported(): boolean {
    return typeof navigator !== "undefined" && "gpu" in navigator;
  }

  get isReady(): boolean {
    return this.status.phase === "ready" && this.engine !== null;
  }

  subscribe(listener: Listener): () => void {
    this.listeners.add(listener);
    listener(this.status);
    return () => this.listeners.delete(listener);
  }

  private setStatus(status: CoachStatus) {
    this.status = status;
    for (const l of this.listeners) l(status);
  }

  private resolveModelId(ids: string[]): string {
    for (const preferred of PREFERRED_MODELS) {
      const hit = ids.find((id) => id === preferred);
      if (hit) return hit;
    }
    // Last resort: any small Qwen/Smol model.
    return ids.find((id) => /Qwen2\.5-0\.5B|Qwen3-0\.6B|SmolLM2-360M/.test(id)) ?? ids[0];
  }

  /** Downloads (once, then cached) and initializes the engine. Idempotent. */
  async ensureLoaded(): Promise<MLCEngineInterface> {
    if (this.engine) return this.engine;
    if (this.loadPromise) return this.loadPromise;
    if (!this.supported) {
      this.setStatus({
        phase: "error",
        message: "WebGPU isn't available in this browser. Try Chrome/Edge or Safari 18+.",
      });
      throw new Error("WebGPU unavailable");
    }

    this.setStatus({ phase: "loading", progress: 0, text: "Preparing model…" });

    // Lazy-load WebLLM so its large bundle is only fetched when the coach is
    // actually used (keeps the initial app load light).
    this.loadPromise = import("@mlc-ai/web-llm")
      .then(({ CreateWebWorkerMLCEngine, prebuiltAppConfig }) => {
        const ids = prebuiltAppConfig.model_list.map((m) => m.model_id);
        const modelId = this.resolveModelId(ids);
        return CreateWebWorkerMLCEngine(
          new Worker(new URL("./llm.worker.ts", import.meta.url), { type: "module" }),
          modelId,
          {
            initProgressCallback: (report: InitProgressReport) =>
              this.setStatus({ phase: "loading", progress: report.progress, text: report.text }),
          },
        );
      })
      .then((engine) => {
        this.engine = engine;
        this.setStatus({ phase: "ready" });
        return engine;
      })
      .catch((err) => {
        this.loadPromise = null;
        this.setStatus({ phase: "error", message: String(err?.message ?? err) });
        throw err;
      });

    return this.loadPromise;
  }

  async unload(): Promise<void> {
    if (this.engine) await this.engine.unload();
    this.engine = null;
    this.loadPromise = null;
    this.setStatus({ phase: "idle" });
  }

  /**
   * Generates warm coaching prose grounded in the deterministic scores. Throws
   * on any failure so the caller can fall back to the rule-based coach. The
   * concrete ritual nudge is kept from the rule-based coach for reliability.
   */
  async coaching(
    profile: UserProfile | undefined,
    scores: EnergyScores,
    bottleneckRaw?: string,
    missedGoals: string[] = [],
  ): Promise<CoachResult> {
    const engine = await this.ensureLoaded();
    const fallback = coachingFor(profile, scores, bottleneckRaw, missedGoals);
    const messages = buildMessages(profile, scores, bottleneckRaw, missedGoals);

    const reply = await engine.chat.completions.create({
      messages,
      temperature: 0.7,
      max_tokens: 180,
    });
    const text = reply.choices[0]?.message?.content?.trim();
    if (!text) throw new Error("Empty completion");
    return { coaching: text, ritualNudge: fallback.ritualNudge };
  }

  /**
   * Best-effort reword of the daily questions so they nod to the user's purpose
   * and ritual goals. Keeps each question's id/energy/scale; only the visible
   * `text` may change. Throws on any parsing/validation issue so the caller can
   * fall back to the deterministic personalization.
   */
  async rephraseQuestions(
    profile: UserProfile,
    questions: CheckInQuestion[],
  ): Promise<CheckInQuestion[]> {
    const engine = await this.ensureLoaded();

    const goals = (["physical", "emotional", "mental", "spiritual"] as Energy[])
      .map((e) => {
        const g =
          e === "physical"
            ? profile.goalPhysical
            : e === "emotional"
              ? profile.goalEmotional
              : e === "mental"
                ? profile.goalMental
                : profile.goalSpiritual;
        return g?.trim() ? `${ENERGY_TITLE[e]}: ${g.trim()}` : null;
      })
      .filter(Boolean)
      .join("; ");

    const system =
      "You reword daily self-check-in questions so they feel personal to this user, " +
      "nodding to their purpose and ritual goals. Keep the EXACT same meaning, the same " +
      "0–10 self-rating scale, and stay concise (max 26 words each). Do not add, remove, or " +
      "merge questions. Reply with ONLY a JSON object mapping each given question id to its " +
      "reworded text, e.g. {\"physical-1\":\"…\"}. No commentary.";
    const user = JSON.stringify({
      purpose: profile.purpose?.trim() ?? "",
      ritualGoals: goals,
      questions: questions.map((q) => ({ id: q.id, energy: q.energy, text: q.text })),
    });

    const reply = await engine.chat.completions.create({
      messages: [
        { role: "system", content: system },
        { role: "user", content: user },
      ],
      temperature: 0.4,
      max_tokens: 400,
    });

    const raw = reply.choices[0]?.message?.content ?? "";
    const start = raw.indexOf("{");
    const end = raw.lastIndexOf("}");
    if (start < 0 || end <= start) throw new Error("No JSON object in reply");
    const map = JSON.parse(raw.slice(start, end + 1)) as Record<string, unknown>;

    // Apply only valid, non-empty string rewrites; keep the rest unchanged.
    let changed = 0;
    const result = questions.map((q) => {
      const v = map[q.id];
      if (typeof v === "string" && v.trim().length >= 8 && v.length <= 240) {
        changed++;
        return { ...q, text: v.trim() };
      }
      return q;
    });
    if (changed === 0) throw new Error("No usable rewrites");
    return result;
  }
}

export const aiCoach = new AICoachManager();

// MARK: - Prompt

function buildMessages(
  profile: UserProfile | undefined,
  scores: EnergyScores,
  bottleneckRaw?: string,
  missedGoals: string[] = [],
): { role: "system" | "user"; content: string }[] {
  const weakest = (bottleneckRaw as Energy) ?? computeBottleneck(scores);
  const bal = computeBalance(scores);

  const system =
    "You are a warm, concise energy-management coach grounded in Loehr & Schwartz's " +
    "\"The Power of Full Engagement\". The user has just completed a Yes/No daily goal check-in. " +
    "Your job is to comment ONLY on the goals they MISSED today (if any), and suggest one " +
    "concrete, actionable next step for each missed goal. If all goals were met, give a short " +
    "positive reinforcement. Write 2–3 sentences in second person. Do NOT mention raw numbers " +
    "or scores, do not use lists, and do not invent facts beyond what you're given. Keep it human and calm.";

  const purpose = profile?.purpose?.trim();
  const missedSection =
    missedGoals.length === 0
      ? "The user completed ALL their goals today."
      : `The user missed these goals today: ${missedGoals.map((g) => `"${g}"`).join(", ")}.`;

  const user =
    `${missedSection} ` +
    `Today's energy balance: ${bal}/100. Weakest energy: ${ENERGY_TITLE[weakest]}.` +
    (purpose ? ` The person's stated purpose: "${purpose}".` : "") +
    " Write their coaching message for today.";

  return [
    { role: "system", content: system },
    { role: "user", content: user },
  ];
}
