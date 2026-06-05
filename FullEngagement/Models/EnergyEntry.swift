import Foundation
import SwiftData

/// One check-in per calendar day (enforced in `EnergyStore` via upsert).
///
/// All properties have defaults for CloudKit compatibility.
@Model
final class EnergyEntry {
    var date: Date = Date.startOfToday          // normalized to start-of-day
    var physical: Int = 0                        // 0...100
    var emotional: Int = 0
    var mental: Int = 0
    var spiritual: Int = 0
    var recovery: Int = 0                        // 0...100 oscillation (spend↔renew)
    var bottleneck: String = Energy.physical.rawValue
    var coaching: String = ""                    // coach prose (model or rule-based)
    var ritualNudge: String = ""
    var note: String?
    var rawAnswers: Data?                         // encoded [String: Int] for audit/export
    var createdAt: Date = Date()

    init(date: Date = .startOfToday,
         physical: Int = 0,
         emotional: Int = 0,
         mental: Int = 0,
         spiritual: Int = 0,
         recovery: Int = 0,
         bottleneck: String = Energy.physical.rawValue,
         coaching: String = "",
         ritualNudge: String = "",
         note: String? = nil,
         rawAnswers: Data? = nil,
         createdAt: Date = Date()) {
        self.date = date
        self.physical = physical
        self.emotional = emotional
        self.mental = mental
        self.spiritual = spiritual
        self.recovery = recovery
        self.bottleneck = bottleneck
        self.coaching = coaching
        self.ritualNudge = ritualNudge
        self.note = note
        self.rawAnswers = rawAnswers
        self.createdAt = createdAt
    }

    // MARK: Derived

    var scores: EnergyScores {
        EnergyScores(physical: physical, emotional: emotional,
                     mental: mental, spiritual: spiritual, recovery: recovery)
    }

    /// Derived, not persisted redundantly (Section 4).
    var balanceScore: Int { scores.balance }

    var bottleneckEnergy: Energy { Energy(rawValue: bottleneck) ?? .physical }

    func value(for energy: Energy) -> Int { scores[energy] }

    var decodedRawAnswers: [String: Int] {
        guard let data = rawAnswers,
              let dict = try? JSONDecoder().decode([String: Int].self, from: data)
        else { return [:] }
        return dict
    }

    func setRawAnswers(_ answers: [String: Int]) {
        rawAnswers = try? JSONEncoder().encode(answers)
    }
}

// MARK: - Date helpers

extension Date {
    nonisolated static var startOfToday: Date {
        Calendar.current.startOfDay(for: Date())
    }

    nonisolated var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
}
