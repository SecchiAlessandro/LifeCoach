// Coach factory — picks the on-device AI coach when it's enabled and the model
// is loaded, otherwise the deterministic rule-based coach. Port of CoachFactory
// in Coach/CoachService.swift. Scoring is never delegated here.

import type { EnergyScores } from "../models/energy";
import type { UserProfile } from "../store/db";
import { coachingFor, type CoachResult } from "./ruleBasedCoach";
import { aiCoach } from "./aiCoach";

export type CoachSource = "ai" | "rule";
export interface ResolvedCoaching extends CoachResult {
  source: CoachSource;
}

export async function coachFor(
  profile: UserProfile | undefined,
  scores: EnergyScores,
  bottleneckRaw?: string,
  missedGoals: string[] = [],
): Promise<ResolvedCoaching> {
  // Use the AI coach only when enabled AND the model is already loaded (loaded
  // explicitly from Settings) — so a check-in never blocks on a model download.
  if (profile?.coachEnabled && aiCoach.supported && aiCoach.isReady) {
    try {
      const result = await aiCoach.coaching(profile, scores, bottleneckRaw, missedGoals);
      return { ...result, source: "ai" };
    } catch {
      // fall through to the guaranteed rule-based path
    }
  }
  return { ...coachingFor(profile, scores, bottleneckRaw, missedGoals), source: "rule" };
}

export { coachingFor };
export type { CoachResult };
