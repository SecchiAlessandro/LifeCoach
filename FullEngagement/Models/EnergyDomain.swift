import Foundation

// MARK: - Energy

/// The four energies of the Full Engagement pyramid, plus the cross-cutting
/// recovery / oscillation dimension. Order here is the pyramid order
/// (physical = foundation … spiritual = apex).
enum Energy: String, CaseIterable, Identifiable, Codable {
    case physical
    case emotional
    case mental
    case spiritual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .physical:  return "Physical"
        case .emotional: return "Emotional"
        case .mental:    return "Mental"
        case .spiritual: return "Spiritual"
        }
    }

    /// One-line framework blurb shown in the detail sheet (Section 9).
    var blurb: String {
        switch self {
        case .physical:  return "The fuel: capacity to expend & recover."
        case .emotional: return "The quality: positive vs. fear-driven."
        case .mental:    return "The focus: concentration & realistic optimism."
        case .spiritual: return "The why: purpose & deeply held values."
        }
    }

    /// Pyramid level, 0 = foundation. Used by the coach's pyramid reasoning.
    var pyramidLevel: Int {
        switch self {
        case .physical:  return 0
        case .emotional: return 1
        case .mental:    return 2
        case .spiritual: return 3
        }
    }
}

// MARK: - Scores

/// Deterministic scores for a single check-in. Always computed in code,
/// never produced by the model (see Section 7).
struct EnergyScores: Equatable {
    var physical: Int
    var emotional: Int
    var mental: Int
    var spiritual: Int
    var recovery: Int

    subscript(_ energy: Energy) -> Int {
        switch energy {
        case .physical:  return physical
        case .emotional: return emotional
        case .mental:    return mental
        case .spiritual: return spiritual
        }
    }

    var byEnergy: [Energy: Int] {
        [.physical: physical, .emotional: emotional, .mental: mental, .spiritual: spiritual]
    }

    /// Tight spread = high balance. `max(0, 100 - (max - min))`.
    var balance: Int {
        let values = [physical, emotional, mental, spiritual]
        guard let hi = values.max(), let lo = values.min() else { return 0 }
        return max(0, 100 - (hi - lo))
    }

    /// The weakest energy — the system's current floor.
    var bottleneck: Energy {
        byEnergy.min { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value < rhs.value }
            // Tie-break toward the lower pyramid level (the foundation matters more).
            return lhs.key.pyramidLevel < rhs.key.pyramidLevel
        }!.key
    }

    /// True when the physical floor is both weak and the bottleneck — the
    /// coach must flag that it caps everything above it.
    var physicalFloorCapping: Bool {
        physical < 50 && bottleneck == .physical
    }
}

// MARK: - Scoring

enum Scoring {
    /// Maps a slider value (0…10) to a 0…100 score.
    static func score(forAnswers answers: [Int]) -> Int {
        guard !answers.isEmpty else { return 0 }
        let mean = Double(answers.reduce(0, +)) / Double(answers.count)
        return Int((mean * 10).rounded())
    }

    /// Computes deterministic scores from raw answers keyed by question id.
    /// Questions are tagged by energy via the bank.
    static func scores(from rawAnswers: [String: Int]) -> EnergyScores {
        func answers(for energy: Energy) -> [Int] {
            QuestionBank.all
                .filter { $0.energy == energy.rawValue }
                .compactMap { rawAnswers[$0.id] }
        }
        func recoveryAnswers() -> [Int] {
            QuestionBank.all
                .filter { $0.energy == "recovery" }
                .compactMap { rawAnswers[$0.id] }
        }
        return EnergyScores(
            physical:  score(forAnswers: answers(for: .physical)),
            emotional: score(forAnswers: answers(for: .emotional)),
            mental:    score(forAnswers: answers(for: .mental)),
            spiritual: score(forAnswers: answers(for: .spiritual)),
            recovery:  score(forAnswers: recoveryAnswers())
        )
    }
}

// MARK: - Questions

struct CheckInQuestion: Identifiable, Equatable {
    let id: String
    let energy: String   // physical|emotional|mental|spiritual|recovery
    var text: String
    let lowLabel: String
    let highLabel: String

    var energyEnum: Energy? { Energy(rawValue: energy) }
}

/// Literature-grounded question bank (Section 9). The deterministic core —
/// the model may only lightly rephrase `text`.
enum QuestionBank {
    static let all: [CheckInQuestion] = [
        .init(id: "physical-1", energy: "physical",
              text: "How physically rested and energized do you feel right now?",
              lowLabel: "Depleted", highLabel: "Charged"),
        .init(id: "physical-2", energy: "physical",
              text: "Did you move your body and take real breaks today (pausing roughly every 90–120 min)?",
              lowLabel: "Not at all", highLabel: "Consistently"),
        .init(id: "emotional-1", energy: "emotional",
              text: "How positive vs. fear- or deficit-driven have your emotions been today?",
              lowLabel: "Toxic / anxious", highLabel: "Positive / calm"),
        .init(id: "emotional-2", energy: "emotional",
              text: "Could you summon positive emotion under stress today?",
              lowLabel: "Reactive", highLabel: "Steady"),
        .init(id: "mental-1", energy: "mental",
              text: "How well could you sustain focus without constant digital interruption?",
              lowLabel: "Scattered", highLabel: "Deep focus"),
        .init(id: "mental-2", energy: "mental",
              text: "Did you move flexibly between broad and narrow focus, with realistic optimism?",
              lowLabel: "Stuck", highLabel: "Fluid"),
        .init(id: "spiritual-1", energy: "spiritual",
              text: "How connected did today feel to your deeper purpose and values?",
              lowLabel: "Disconnected", highLabel: "Fully aligned"),
        .init(id: "spiritual-2", energy: "spiritual",
              text: "Did your actions today reflect what matters most to you?",
              lowLabel: "Off-course", highLabel: "On-purpose"),
        .init(id: "recovery-1", energy: "recovery",
              text: "How well did you balance effort (expenditure) with renewal (recovery)?",
              lowLabel: "All spend, no rest", highLabel: "Well-oscillated"),
    ]

    static func question(id: String) -> CheckInQuestion? {
        all.first { $0.id == id }
    }

    /// Picks a daily set: one per energy + one recovery, weighting toward the
    /// weakest / stalest energy from recent entries.
    ///
    /// "Stale" = the energy whose dedicated question we've shown least recently.
    /// For simplicity we weight purely by the most recent entry's weakest energy:
    /// for that energy we surface its second question to keep things fresh.
    static func dailySet(recent: [EnergyEntry]) -> [CheckInQuestion] {
        let weakest = recent.first.map { Energy(rawValue: $0.bottleneck) ?? .physical }
        var picked: [CheckInQuestion] = []

        for energy in Energy.allCases {
            let candidates = all.filter { $0.energy == energy.rawValue }
            guard !candidates.isEmpty else { continue }
            // For the weakest energy, alternate to the second question (if any)
            // based on how many entries we already have, to vary the prompt.
            if energy == weakest, candidates.count > 1 {
                let idx = (recent.count) % candidates.count
                picked.append(candidates[idx])
            } else {
                picked.append(candidates[0])
            }
        }
        // Always include the single recovery question.
        if let recovery = all.first(where: { $0.energy == "recovery" }) {
            picked.append(recovery)
        }
        return picked
    }
}
