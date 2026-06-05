import SwiftUI
import SwiftData

/// History tab (Section 6.4): range-toggled multi-line energy trend, balance
/// trend, and ritual streaks.
struct HistoryView: View {
    @Environment(\.colorScheme) private var scheme
    let store: EnergyStore

    enum Range: Int, CaseIterable, Identifiable {
        case d14 = 14, d30 = 30, d90 = 90
        var id: Int { rawValue }
        var label: String { "\(rawValue)d" }
    }

    @State private var range: Range = .d14
    @Query(sort: \Ritual.createdAt) private var rituals: [Ritual]

    private var entries: [EnergyEntry] {
        let since = Calendar.current.date(byAdding: .day, value: -(range.rawValue - 1),
                                          to: .startOfToday)!
        return store.entries(since: since)   // ascending
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Picker("Range", selection: $range) {
                        ForEach(Range.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if entries.isEmpty {
                        emptyState
                    } else {
                        SectionHeader(title: "Four energies")
                        CardView { TrendChart(entries: entries) }

                        SectionHeader(title: "Balance")
                        CardView { BalanceTrendChart(entries: entries) }
                    }

                    if !rituals.isEmpty {
                        SectionHeader(title: "Ritual streaks")
                        ForEach(rituals) { ritual in
                            ritualRow(ritual)
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.background(scheme).ignoresSafeArea())
            .navigationTitle("History")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 40))
                .foregroundStyle(Theme.secondaryText(scheme))
            Text("No check-ins in this range yet.")
                .font(Theme.body(15))
                .foregroundStyle(Theme.secondaryText(scheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func ritualRow(_ ritual: Ritual) -> some View {
        CardView {
            HStack {
                Circle().fill(Theme.color(for: ritual.energyEnum)).frame(width: 12, height: 12)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ritual.text.isEmpty ? ritual.energyEnum.title : ritual.text)
                        .font(Theme.body(15, weight: .medium))
                        .foregroundStyle(Theme.primaryText(scheme))
                    Text(ritual.energyEnum.title)
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.secondaryText(scheme))
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                    Text("\(ritual.streak)")
                }
                .font(Theme.body(15, weight: .bold))
                .foregroundStyle(ritual.doneToday ? Theme.balanceAccent : Theme.secondaryText(scheme))
            }
        }
    }
}
