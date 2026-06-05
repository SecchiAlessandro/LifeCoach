// Daily check-in question preparation. Starts from the deterministic bank
// selection (dailySet) and personalizes the wording to the user's purpose and
// per-energy ritual goals. The question id, energy tag, and 0–10 scale are kept
// intact, so deterministic scoring is unaffected (same contract as the iOS
// CoachService.dailyQuestions — "lightly personalize wording").

import {
  dailySet,
  ENERGY_TITLE,
  questionEnergy,
  type CheckInQuestion,
  type Energy,
} from "../models/energy";
import type { EnergyEntry, UserProfile } from "../store/db";
import { aiCoach } from "./aiCoach";

function goalFor(profile: UserProfile, energy: Energy): string {
  switch (energy) {
    case "physical":
      return profile.goalPhysical;
    case "emotional":
      return profile.goalEmotional;
    case "mental":
      return profile.goalMental;
    case "spiritual":
      return profile.goalSpiritual;
  }
}

/// Deterministic personalization: weave the relevant ritual goal (and, for the
/// spiritual question, the stated purpose) into each question's text.
export function personalizeQuestions(
  profile: UserProfile | undefined,
  questions: CheckInQuestion[],
): CheckInQuestion[] {
  if (!profile) return questions;
  const purpose = profile.purpose?.trim() ?? "";

  return questions.map((q) => {
    const energy = questionEnergy(q);
    if (!energy) return q; // recovery question has no per-energy goal

    const goal = goalFor(profile, energy).trim();
    const parts: string[] = [];
    if (energy === "spiritual" && purpose) parts.push(`your purpose — “${purpose}”`);
    if (goal) parts.push(`your ${ENERGY_TITLE[energy].toLowerCase()} ritual — ${goal}`);
    if (parts.length === 0) return q;

    return { ...q, text: `${q.text} Keep in mind ${parts.join(" and ")}.` };
  });
}

/// Prepares the day's questions: always personalized deterministically, then —
/// when the on-device AI coach is enabled and loaded — best-effort reworded by
/// the model. Any AI failure silently falls back to the deterministic version.
export async function prepareDailyQuestions(
  profile: UserProfile | undefined,
  recent: EnergyEntry[],
): Promise<CheckInQuestion[]> {
  const base = personalizeQuestions(profile, dailySet(recent));

  if (profile?.coachEnabled && aiCoach.supported && aiCoach.isReady) {
    try {
      return await aiCoach.rephraseQuestions(profile, base);
    } catch {
      // fall through to the deterministic personalization
    }
  }
  return base;
}
