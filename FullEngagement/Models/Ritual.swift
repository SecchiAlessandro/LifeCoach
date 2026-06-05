import Foundation
import SwiftData

/// Optional ritual tracking (Milestone 5/6). A specific automatic routine
/// the user commits to for a given energy — "rituals over willpower."
@Model
final class Ritual {
    var energy: String = Energy.physical.rawValue
    var text: String = ""
    var active: Bool = true
    var streak: Int = 0
    var lastDone: Date?
    var createdAt: Date = Date()

    init(energy: String = Energy.physical.rawValue,
         text: String = "",
         active: Bool = true,
         streak: Int = 0,
         lastDone: Date? = nil,
         createdAt: Date = Date()) {
        self.energy = energy
        self.text = text
        self.active = active
        self.streak = streak
        self.lastDone = lastDone
        self.createdAt = createdAt
    }

    var energyEnum: Energy { Energy(rawValue: energy) ?? .physical }

    var doneToday: Bool {
        guard let lastDone else { return false }
        return Calendar.current.isDateInToday(lastDone)
    }

    /// Marks the ritual done for today, extending or resetting the streak.
    func markDoneToday() {
        let cal = Calendar.current
        if let lastDone, cal.isDateInToday(lastDone) {
            return // already counted today
        }
        if let lastDone, cal.isDateInYesterday(lastDone) {
            streak += 1
        } else {
            streak = 1
        }
        lastDone = Date()
    }
}
