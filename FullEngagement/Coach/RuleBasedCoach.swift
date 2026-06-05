import Foundation

/// Deterministic coach (Section 10). The guaranteed path — works on every
/// device and when the on-device model is off. Templates keyed on the
/// bottleneck and whether balance is high / medium / low, with pyramid logic
/// when physical is the floor.
struct RuleBasedCoach: CoachService {

    func dailyQuestions(profile: UserProfile?, recent: [EnergyEntry]) async -> [CheckInQuestion] {
        QuestionBank.dailySet(recent: recent)
    }

    func coaching(profile: UserProfile?,
                  scores: EnergyScores,
                  bottleneck: String,
                  balance: Int) async -> (coaching: String, ritualNudge: String) {
        coachingSync(profile: profile, scores: scores, bottleneck: bottleneck, balance: balance)
    }

    /// Synchronous variant, used for mock seeding and as the async body.
    func coachingSync(profile: UserProfile?,
                      scores: EnergyScores,
                      bottleneck: String,
                      balance: Int) -> (coaching: String, ritualNudge: String) {
        let weakest = Energy(rawValue: bottleneck) ?? scores.bottleneck
        let weakestName = weakest.title
        let goal = profile?.goal(for: weakest) ?? ""

        let coaching: String
        let nudge: String

        switch balance {
        case 75...:
            coaching = "Your four energies are running even today — that balance *is* the goal. " +
                       "Keep the rhythm of spend-and-renew going."
            nudge = goalNudge(
                base: "Protect tomorrow's existing ritual for \(weakestName.lowercased()) energy.",
                goal: goal)

        case 50..<75:
            coaching = "\(weakestName) is your current floor. Because the four reinforce each other, " +
                       "lifting the weakest lifts the whole system."
            nudge = goalNudge(
                base: "One small \(weakestName.lowercased()) ritual tomorrow, treated like an appointment.",
                goal: goal)

        default: // < 50
            var prose = "You're stretched thin on \(weakestName.lowercased()). " +
                        "Don't push the strong ones harder — restore the weak one first."
            if scores.physicalFloorCapping {
                prose += " Physical is the foundation: a weak physical floor caps everything above it, " +
                         "so start there."
            }
            coaching = prose
            nudge = goalNudge(
                base: renewalRitual(for: weakest),
                goal: goal)
        }

        return (coaching, nudge)
    }

    // MARK: - Helpers

    private func goalNudge(base: String, goal: String) -> String {
        guard !goal.trimmingCharacters(in: .whitespaces).isEmpty else { return base }
        return "\(base) Your ritual: \(goal)"
    }

    private func renewalRitual(for energy: Energy) -> String {
        switch energy {
        case .physical:
            return "A concrete renewal ritual: a 10-minute walk and lights-out at a fixed time tonight."
        case .emotional:
            return "A concrete renewal ritual: three slow breaths and one gratitude note before bed."
        case .mental:
            return "A concrete renewal ritual: one 90-minute focus block tomorrow, phone in another room."
        case .spiritual:
            return "A concrete renewal ritual: five quiet minutes tomorrow on why today's work matters."
        }
    }
}
