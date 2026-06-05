import SwiftUI
import SwiftData

/// The Today tab (Section 6.2): the Energy Wheel, balance hero metric, coach
/// card, and the check-in CTA.
struct DashboardView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var context

    let store: EnergyStore

    @State private var showCheckIn = false
    @State private var selectedEnergy: Energy?

    private var today: EnergyEntry? { store.todaysEntry() }
    private var scores: EnergyScores {
        today?.scores ?? EnergyScores(physical: 0, emotional: 0, mental: 0, spiritual: 0, recovery: 0)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header

                EnergyWheel(scores: scores) { energy in
                    selectedEnergy = energy
                }
                .frame(maxWidth: 360)
                .padding(.horizontal, 8)

                balanceHero

                if let today {
                    coachCard(today)
                }

                cta
            }
            .padding(20)
        }
        .background(Theme.background(scheme).ignoresSafeArea())
        .sheet(isPresented: $showCheckIn) {
            CheckInView(store: store)
        }
        .sheet(item: $selectedEnergy) { energy in
            EnergyDetailSheet(energy: energy, store: store)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(spacing: 4) {
            Text(Date.now, format: .dateTime.weekday(.wide).month().day())
                .font(Theme.body(14, weight: .semibold))
                .foregroundStyle(Theme.secondaryText(scheme))
            Text("Full Engagement")
                .font(Theme.display(30, weight: .bold))
                .foregroundStyle(Theme.primaryText(scheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var balanceHero: some View {
        VStack(spacing: 6) {
            Text("\(scores.balance)")
                .font(Theme.display(64, weight: .bold))
                .foregroundStyle(Theme.balanceAccent)
            Text(balanceRead)
                .font(Theme.body(15))
                .foregroundStyle(Theme.secondaryText(scheme))
                .multilineTextAlignment(.center)
        }
    }

    private var balanceRead: String {
        guard today != nil else { return "No check-in yet today — your wheel is waiting." }
        switch scores.balance {
        case 75...:  return "Your energies are running even. That balance is the goal."
        case 50..<75: return "\(scores.bottleneck.title) is your current floor — lift the weakest."
        default:      return "You're out of balance. Restore \(scores.bottleneck.title.lowercased()) first."
        }
    }

    private func coachCard(_ entry: EnergyEntry) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Coach").font(Theme.body(13, weight: .bold))
                    Spacer()
                    PillLabel(text: "Floor: \(entry.bottleneckEnergy.title)",
                              color: Theme.color(for: entry.bottleneckEnergy))
                }
                .foregroundStyle(Theme.secondaryText(scheme))

                Text(entry.coaching)
                    .font(Theme.body(16))
                    .foregroundStyle(Theme.primaryText(scheme))

                if !entry.ritualNudge.isEmpty {
                    Divider()
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checklist")
                        Text(entry.ritualNudge)
                            .font(Theme.body(14))
                    }
                    .foregroundStyle(Theme.secondaryText(scheme))
                }
            }
        }
    }

    private var cta: some View {
        PrimaryButton(
            title: today == nil ? "Begin daily check-in" : "Update today's check-in",
            systemImage: today == nil ? "play.fill" : "arrow.clockwise"
        ) {
            showCheckIn = true
        }
    }
}

/// Tap-to-detail sheet (Section 5): % , goal, 14-day mini-trend, framework blurb.
struct EnergyDetailSheet: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    let energy: Energy
    let store: EnergyStore

    private var profile: UserProfile? { store.currentProfile() }
    private var current: Int { store.todaysEntry()?.value(for: energy) ?? 0 }

    private var miniTrend: [Double] {
        let cal = Calendar.current
        let since = cal.date(byAdding: .day, value: -13, to: .startOfToday)!
        return store.entries(since: since).map { Double($0.value(for: energy)) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Circle().fill(Theme.color(for: energy)).frame(width: 14, height: 14)
                Text(energy.title).font(Theme.display(28, weight: .bold))
                Spacer()
                Text("\(current)")
                    .font(Theme.display(36, weight: .bold))
                    .foregroundStyle(Theme.color(for: energy))
            }

            Text(energy.blurb)
                .font(Theme.body(15))
                .foregroundStyle(Theme.secondaryText(scheme))

            if let goal = profile?.goal(for: energy), !goal.isEmpty {
                CardView {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your ritual goal").font(Theme.body(12, weight: .bold))
                            .foregroundStyle(Theme.secondaryText(scheme))
                        Text(goal).font(Theme.body(16))
                            .foregroundStyle(Theme.primaryText(scheme))
                    }
                }
            }

            Text("Last 14 days").font(Theme.body(12, weight: .bold))
                .foregroundStyle(Theme.secondaryText(scheme))
            Sparkline(values: miniTrend, color: Theme.color(for: energy))
                .frame(height: 60)

            Spacer()
        }
        .padding(24)
        .background(Theme.background(scheme).ignoresSafeArea())
    }
}

/// A tiny inline trend line for the detail sheet.
struct Sparkline: View {
    var values: [Double]
    var color: Color

    var body: some View {
        GeometryReader { geo in
            let maxV = max(values.max() ?? 100, 1)
            let count = max(values.count - 1, 1)
            Path { p in
                for (i, v) in values.enumerated() {
                    let x = geo.size.width * CGFloat(i) / CGFloat(count)
                    let y = geo.size.height * (1 - CGFloat(v / maxV))
                    if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                    else { p.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
    }
}
