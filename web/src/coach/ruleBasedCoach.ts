// Port of Coach/RuleBasedCoach.swift — the guaranteed, deterministic coaching
// path. Templates keyed on the bottleneck and the balance band, with pyramid
// logic when physical is the floor.

import {
  type Energy,
  type EnergyScores,
  ENERGY_TITLE,
  balance as computeBalance,
  bottleneck as computeBottleneck,
  physicalFloorCapping,
} from "../models/energy";
import type { UserProfile } from "../store/db";

export interface CoachResult {
  coaching: string;
  ritualNudge: string;
}

function goalFor(profile: UserProfile | undefined, energy: Energy): string {
  if (!profile) return "";
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

function goalNudge(base: string, goal: string): string {
  if (goal.trim().length === 0) return base;
  return `${base} Your ritual: ${goal}`;
}

function renewalRitual(energy: Energy): string {
  switch (energy) {
    case "physical":
      return "A concrete renewal ritual: a 10-minute walk and lights-out at a fixed time tonight.";
    case "emotional":
      return "A concrete renewal ritual: three slow breaths and one gratitude note before bed.";
    case "mental":
      return "A concrete renewal ritual: one 90-minute focus block tomorrow, phone in another room.";
    case "spiritual":
      return "A concrete renewal ritual: five quiet minutes tomorrow on why today's work matters.";
  }
}

/// Returns ONLY prose + nudge. Scores are computed deterministically elsewhere.
export function coachingFor(
  profile: UserProfile | undefined,
  scores: EnergyScores,
  bottleneckRaw?: string,
): CoachResult {
  const weakest = (bottleneckRaw as Energy) ?? computeBottleneck(scores);
  const weakestName = ENERGY_TITLE[weakest];
  const goal = goalFor(profile, weakest);
  const bal = computeBalance(scores);

  let coaching: string;
  let nudge: string;

  if (bal >= 75) {
    coaching =
      "Your four energies are running even today — that balance *is* the goal. " +
      "Keep the rhythm of spend-and-renew going.";
    nudge = goalNudge(
      `Protect tomorrow's existing ritual for ${weakestName.toLowerCase()} energy.`,
      goal,
    );
  } else if (bal >= 50) {
    coaching =
      `${weakestName} is your current floor. Because the four reinforce each other, ` +
      "lifting the weakest lifts the whole system.";
    nudge = goalNudge(
      `One small ${weakestName.toLowerCase()} ritual tomorrow, treated like an appointment.`,
      goal,
    );
  } else {
    let prose =
      `You're stretched thin on ${weakestName.toLowerCase()}. ` +
      "Don't push the strong ones harder — restore the weak one first.";
    if (physicalFloorCapping(scores)) {
      prose +=
        " Physical is the foundation: a weak physical floor caps everything above it, " +
        "so start there.";
    }
    coaching = prose;
    nudge = goalNudge(renewalRitual(weakest), goal);
  }

  return { coaching, ritualNudge: nudge };
}
