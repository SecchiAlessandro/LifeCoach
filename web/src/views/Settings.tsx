// Settings tab (Section 6.5) — edit purpose & goals, export data, privacy note.
// Port of Views/Settings/SettingsView.swift. The on-device model picker is
// replaced with a parity note (on-device AI is iOS-only for now).

import { useEffect, useState } from "react";
import { ENERGIES, ENERGY_TITLE, type Energy } from "../models/energy";
import { energyHex } from "../theme/theme";
import { useProfile } from "../store/useStore";
import { exportCSV, exportJSON, updateProfile } from "../store/energyStore";
import { Card } from "../components/ui";
import type { UserProfile } from "../store/db";
import { useAICoachStatus } from "../coach/useAICoach";
import {
  aiCoach,
  AI_MODEL_APPROX_MB,
  AI_MODEL_LABEL,
  AI_MODEL_LICENSE,
} from "../coach/aiCoach";

type GoalKey = "goalPhysical" | "goalEmotional" | "goalMental" | "goalSpiritual";
const GOAL_KEY: Record<Energy, GoalKey> = {
  physical: "goalPhysical",
  emotional: "goalEmotional",
  mental: "goalMental",
  spiritual: "goalSpiritual",
};

function download(filename: string, content: string, type: string) {
  const blob = new Blob([content], { type });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

export function Settings() {
  const profile = useProfile();
  const [draft, setDraft] = useState<Partial<UserProfile>>({});

  // Seed the local draft once the profile loads.
  useEffect(() => {
    if (profile) setDraft(profile);
  }, [profile?.id]);

  function setField(key: keyof UserProfile, value: string) {
    setDraft((d) => ({ ...d, [key]: value }));
  }
  function save(key: keyof UserProfile) {
    void updateProfile({ [key]: draft[key] } as Partial<UserProfile>);
  }

  return (
    <div className="mx-auto flex max-w-[480px] flex-col gap-6 px-5 py-6">
      <h1 className="font-display text-[30px] font-bold text-primary">Settings</h1>

      <Section title="Purpose">
        <textarea
          value={draft.purpose ?? ""}
          onChange={(e) => setField("purpose", e.target.value)}
          onBlur={() => save("purpose")}
          rows={3}
          className="w-full resize-none rounded-[12px] bg-surface p-3 text-[15px] text-primary outline-none"
        />
      </Section>

      <Section title="Ritual goals">
        <div className="flex flex-col gap-3">
          {ENERGIES.map((energy) => {
            const key = GOAL_KEY[energy];
            return (
              <div key={energy} className="flex items-center gap-2">
                <span className="inline-block h-2.5 w-2.5 shrink-0 rounded-full" style={{ background: energyHex(energy) }} />
                <input
                  type="text"
                  placeholder={`${ENERGY_TITLE[energy]} ritual`}
                  value={(draft[key] as string) ?? ""}
                  onChange={(e) => setField(key, e.target.value)}
                  onBlur={() => save(key)}
                  className="w-full rounded-[12px] bg-surface p-3 text-[15px] text-primary outline-none"
                />
              </div>
            );
          })}
        </div>
      </Section>

      <Section title="Export">
        <div className="flex flex-col gap-2">
          <button
            onClick={async () => download("FullEngagement.json", await exportJSON(), "application/json")}
            className="rounded-[12px] bg-surface p-3 text-left text-[15px] text-primary"
          >
            ⬆️ Export JSON
          </button>
          <button
            onClick={async () => download("FullEngagement.csv", await exportCSV(), "text/csv")}
            className="rounded-[12px] bg-surface p-3 text-left text-[15px] text-primary"
          >
            🧮 Export CSV
          </button>
        </div>
      </Section>

      <Section title="Coaching">
        <CoachingSection coachEnabled={profile?.coachEnabled ?? false} />
      </Section>

      <Section title="Privacy">
        <Card>
          <p className="text-[13px] text-secondary">
            Your check-ins live only in this browser, in local (IndexedDB) storage. We run no server. Export
            your data anytime above.
          </p>
        </Card>
      </Section>

      <Section title="About">
        <div className="flex flex-col gap-1 text-[15px] text-primary">
          <Row label="Framework" value="Loehr & Schwartz" />
          <Row label="Version" value="1.0" />
        </div>
      </Section>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="flex flex-col gap-2">
      <h2 className="text-[13px] font-bold uppercase tracking-wide text-secondary">{title}</h2>
      {children}
    </section>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between">
      <span className="text-secondary">{label}</span>
      <span>{value}</span>
    </div>
  );
}

/// On-device AI coach controls — enable toggle + model download/status. The web
/// analog of the Coaching section + ModelDownloadView in SettingsView.swift.
function CoachingSection({ coachEnabled }: { coachEnabled: boolean }) {
  const status = useAICoachStatus();
  const supported = aiCoach.supported;

  async function toggle(next: boolean) {
    await updateProfile({ coachEnabled: next });
    if (next && supported && status.phase === "idle") {
      // Kick off the one-time model download so check-ins use it promptly.
      void aiCoach.ensureLoaded().catch(() => {});
    }
  }

  return (
    <Card>
      <div className="flex items-center justify-between">
        <span className="text-[15px] font-medium text-primary">On-device AI coach</span>
        <Toggle checked={coachEnabled} disabled={!supported} onChange={toggle} />
      </div>

      {!supported && (
        <p className="mt-2 text-[13px] text-secondary">
          WebGPU isn't available in this browser, so the AI coach can't run. Try Chrome/Edge or Safari 18+.
          The rule-based coach works everywhere.
        </p>
      )}

      {supported && coachEnabled && (
        <div className="mt-3 flex flex-col gap-2">
          <div className="flex justify-between text-[13px] text-secondary">
            <span>Model</span>
            <span>{AI_MODEL_LABEL}</span>
          </div>
          <div className="flex justify-between text-[13px] text-secondary">
            <span>Download size · license</span>
            <span>
              ~{AI_MODEL_APPROX_MB} MB · {AI_MODEL_LICENSE}
            </span>
          </div>

          {status.phase === "loading" && (
            <div className="mt-1 flex flex-col gap-1">
              <div className="h-1.5 w-full overflow-hidden rounded-full" style={{ background: "var(--hairline)" }}>
                <div
                  className="h-full rounded-full bg-accent transition-all"
                  style={{ width: `${Math.round(status.progress * 100)}%` }}
                />
              </div>
              <span className="text-[12px] text-secondary">{status.text}</span>
            </div>
          )}

          {status.phase === "ready" && (
            <span className="text-[13px] font-semibold text-accent">✓ Model ready — check-ins will use it</span>
          )}

          {status.phase === "error" && (
            <div className="flex flex-col gap-1">
              <span className="text-[13px] text-red-500">{status.message}</span>
              <button
                className="self-start rounded-[10px] bg-surface px-3 py-1.5 text-[13px] text-primary"
                style={{ border: "1px solid var(--hairline)" }}
                onClick={() => void aiCoach.ensureLoaded().catch(() => {})}
              >
                Retry download
              </button>
            </div>
          )}

          {status.phase === "idle" && (
            <button
              className="self-start rounded-[10px] bg-surface px-3 py-1.5 text-[13px] text-primary"
              style={{ border: "1px solid var(--hairline)" }}
              onClick={() => void aiCoach.ensureLoaded().catch(() => {})}
            >
              Download &amp; load model
            </button>
          )}
        </div>
      )}

      <p className="mt-3 text-[12px] text-secondary">
        When on (and loaded), coaching prose is generated by an open-source model running entirely in your
        browser — prompts never leave this device. Scoring is always deterministic and identical either way.
      </p>
    </Card>
  );
}

/// A small iOS-style switch.
function Toggle({
  checked,
  disabled,
  onChange,
}: {
  checked: boolean;
  disabled?: boolean;
  onChange: (next: boolean) => void;
}) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      disabled={disabled}
      onClick={() => onChange(!checked)}
      className="relative h-[30px] w-[50px] rounded-full transition-colors disabled:opacity-40"
      style={{ background: checked ? "var(--color-accent)" : "var(--hairline)" }}
    >
      <span
        className="absolute top-[3px] h-[24px] w-[24px] rounded-full bg-white transition-all"
        style={{ left: checked ? 23 : 3, boxShadow: "0 1px 3px rgba(0,0,0,0.3)" }}
      />
    </button>
  );
}
