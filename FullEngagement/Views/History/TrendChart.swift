import SwiftUI
import Charts

/// Multi-line trend of the four energies over time (Section 6.4), plus a
/// dedicated balance trend. Built on Swift Charts.
struct TrendChart: View {
    @Environment(\.colorScheme) private var scheme
    var entries: [EnergyEntry]   // ascending by date

    var body: some View {
        Chart {
            ForEach(Energy.allCases) { energy in
                ForEach(entries, id: \.date) { entry in
                    LineMark(
                        x: .value("Date", entry.date),
                        y: .value("Score", entry.value(for: energy))
                    )
                    .foregroundStyle(by: .value("Energy", energy.title))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                }
            }
        }
        .chartForegroundStyleScale(energyColorScale)
        .chartYScale(domain: 0...100)
        .chartLegend(position: .bottom, spacing: 12)
        .frame(height: 240)
    }

    private var energyColorScale: KeyValuePairs<String, Color> {
        [
            Energy.physical.title:  Theme.color(for: .physical),
            Energy.mental.title:    Theme.color(for: .mental),
            Energy.emotional.title: Theme.color(for: .emotional),
            Energy.spiritual.title: Theme.color(for: .spiritual),
        ]
    }
}

/// The balance score over time — the headline metric's trend.
struct BalanceTrendChart: View {
    var entries: [EnergyEntry]

    var body: some View {
        Chart(entries, id: \.date) { entry in
            AreaMark(
                x: .value("Date", entry.date),
                y: .value("Balance", entry.balanceScore)
            )
            .foregroundStyle(
                LinearGradient(colors: [Theme.balanceAccent.opacity(0.4), .clear],
                               startPoint: .top, endPoint: .bottom)
            )
            .interpolationMethod(.catmullRom)

            LineMark(
                x: .value("Date", entry.date),
                y: .value("Balance", entry.balanceScore)
            )
            .foregroundStyle(Theme.balanceAccent)
            .lineStyle(StrokeStyle(lineWidth: 2.5))
            .interpolationMethod(.catmullRom)
        }
        .chartYScale(domain: 0...100)
        .frame(height: 160)
    }
}
