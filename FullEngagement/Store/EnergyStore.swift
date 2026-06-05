import Foundation
import SwiftData

/// Owns SwiftData access for entries and profile: upsert-today, queries,
/// seeding, and export. Views talk to this rather than the context directly.
@Observable
@MainActor
final class EnergyStore {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Profile

    func currentProfile() -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfile>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return (try? context.fetch(descriptor))?.first
    }

    @discardableResult
    func ensureProfile() -> UserProfile {
        if let existing = currentProfile() { return existing }
        let profile = UserProfile()
        context.insert(profile)
        try? context.save()
        return profile
    }

    var hasCompletedOnboarding: Bool {
        currentProfile() != nil
    }

    // MARK: - Entries

    func allEntries() -> [EnergyEntry] {
        let descriptor = FetchDescriptor<EnergyEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Recent entries, most-recent first.
    func recentEntries(limit: Int = 30) -> [EnergyEntry] {
        var descriptor = FetchDescriptor<EnergyEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    func entries(since date: Date) -> [EnergyEntry] {
        let start = date.startOfDay
        let descriptor = FetchDescriptor<EnergyEntry>(
            predicate: #Predicate { $0.date >= start },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func todaysEntry() -> EnergyEntry? {
        entry(on: .startOfToday)
    }

    func entry(on day: Date) -> EnergyEntry? {
        let start = day.startOfDay
        // Compare on the normalized start-of-day stored value.
        let descriptor = FetchDescriptor<EnergyEntry>(
            predicate: #Predicate { $0.date == start }
        )
        return (try? context.fetch(descriptor))?.first
    }

    /// Upserts one entry for the given day (default: today). Enforces one per
    /// calendar day (Section 4).
    @discardableResult
    func upsert(day: Date = .startOfToday,
                scores: EnergyScores,
                coaching: String,
                ritualNudge: String,
                rawAnswers: [String: Int],
                note: String?) -> EnergyEntry {
        let start = day.startOfDay
        let entry = entry(on: start) ?? {
            let e = EnergyEntry(date: start)
            context.insert(e)
            return e
        }()

        entry.physical = scores.physical
        entry.emotional = scores.emotional
        entry.mental = scores.mental
        entry.spiritual = scores.spiritual
        entry.recovery = scores.recovery
        entry.bottleneck = scores.bottleneck.rawValue
        entry.coaching = coaching
        entry.ritualNudge = ritualNudge
        entry.note = note
        entry.setRawAnswers(rawAnswers)

        try? context.save()
        return entry
    }

    func delete(_ entry: EnergyEntry) {
        context.delete(entry)
        try? context.save()
    }

    // MARK: - Mock seeding (Milestone 1/2)

    /// Seeds N days of plausible mock entries if the store is empty.
    func seedMockDataIfEmpty(days: Int = 21) {
        guard allEntries().isEmpty else { return }
        let cal = Calendar.current
        let coach = RuleBasedCoach()

        for offset in stride(from: days - 1, through: 0, by: -1) {
            guard let day = cal.date(byAdding: .day, value: -offset, to: .startOfToday) else { continue }
            let phase = Double(days - offset)
            func wave(_ base: Int, _ amp: Int, _ shift: Double) -> Int {
                let v = Double(base) + Double(amp) * sin((phase + shift) / 3.0)
                return min(100, max(0, Int(v.rounded())))
            }
            let scores = EnergyScores(
                physical:  wave(62, 18, 0),
                emotional: wave(58, 22, 1.5),
                mental:    wave(66, 16, 3),
                spiritual: wave(54, 20, 4.5),
                recovery:  wave(60, 25, 2)
            )
            let result = coach.coachingSync(profile: nil, scores: scores,
                                            bottleneck: scores.bottleneck.rawValue,
                                            balance: scores.balance)
            upsert(day: day, scores: scores,
                   coaching: result.coaching, ritualNudge: result.ritualNudge,
                   rawAnswers: [:], note: nil)
        }
    }

    // MARK: - Export (Milestone 4)

    func exportJSON() -> Data {
        let payload = allEntries()
            .sorted { $0.date < $1.date }
            .map { ExportRow(from: $0) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(payload)) ?? Data()
    }

    func exportCSV() -> String {
        let formatter = ISO8601DateFormatter()
        var lines = ["date,physical,emotional,mental,spiritual,recovery,balance,bottleneck,note"]
        for entry in allEntries().sorted(by: { $0.date < $1.date }) {
            let note = (entry.note ?? "")
                .replacingOccurrences(of: "\"", with: "\"\"")
            let fields = [
                formatter.string(from: entry.date),
                "\(entry.physical)", "\(entry.emotional)", "\(entry.mental)",
                "\(entry.spiritual)", "\(entry.recovery)", "\(entry.balanceScore)",
                entry.bottleneck,
                "\"\(note)\""
            ]
            lines.append(fields.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }
}

/// Codable snapshot used for JSON export.
struct ExportRow: Codable {
    let date: Date
    let physical: Int
    let emotional: Int
    let mental: Int
    let spiritual: Int
    let recovery: Int
    let balance: Int
    let bottleneck: String
    let coaching: String
    let ritualNudge: String
    let note: String?
    let answers: [String: Int]

    init(from entry: EnergyEntry) {
        date = entry.date
        physical = entry.physical
        emotional = entry.emotional
        mental = entry.mental
        spiritual = entry.spiritual
        recovery = entry.recovery
        balance = entry.balanceScore
        bottleneck = entry.bottleneck
        coaching = entry.coaching
        ritualNudge = entry.ritualNudge
        note = entry.note
        answers = entry.decodedRawAnswers
    }
}
