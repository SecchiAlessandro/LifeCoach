import SwiftUI
import SwiftData

/// Onboarding / Setup (Section 6.1): purpose statement + one ritual-shaped goal
/// per energy + model-download consent. Writes the single `UserProfile`.
struct SetupView: View {
    @Environment(\.colorScheme) private var scheme
    let store: EnergyStore
    /// Called when setup completes so the app can route to the dashboard.
    var onComplete: () -> Void

    @State private var step = 0
    @State private var purpose = "Is the life I am living worth what I'm giving up to have it?"
    @State private var goals: [Energy: String] = [:]
    @State private var enableCoach = false

    private let totalSteps = 3

    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: Double(step + 1), total: Double(totalSteps))
                .tint(Theme.balanceAccent)
                .padding()

            TabView(selection: $step) {
                purposeStep.tag(0)
                goalsStep.tag(1)
                coachStep.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: step)

            footer
        }
        .background(Theme.background(scheme).ignoresSafeArea())
    }

    // MARK: - Steps

    private var purposeStep: some View {
        stepScaffold(
            title: "Your why",
            subtitle: "Spiritual energy is the apex of the pyramid — a purpose beyond self-interest. Start there."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text("What is your purpose?")
                    .font(Theme.body(14, weight: .bold))
                    .foregroundStyle(Theme.secondaryText(scheme))
                TextField("Your purpose", text: $purpose, axis: .vertical)
                    .lineLimit(3...6)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface(scheme)))
            }
        }
    }

    private var goalsStep: some View {
        stepScaffold(
            title: "One ritual each",
            subtitle: "Progress comes from specific automatic routines, not willpower. Name one small ritual per energy."
        ) {
            VStack(spacing: 14) {
                ForEach(Energy.allCases) { energy in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Circle().fill(Theme.color(for: energy)).frame(width: 10, height: 10)
                            Text(energy.title).font(Theme.body(14, weight: .bold))
                            Spacer()
                            Text(energy.blurb).font(Theme.body(11))
                                .foregroundStyle(Theme.secondaryText(scheme))
                        }
                        TextField(placeholder(for: energy),
                                  text: Binding(get: { goals[energy] ?? "" },
                                                set: { goals[energy] = $0 }))
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface(scheme)))
                    }
                }
            }
        }
    }

    private var coachStep: some View {
        stepScaffold(
            title: "Your coach",
            subtitle: "An optional on-device AI can warm up the coaching prose. Everything stays on your phone."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Enable on-device AI coach", isOn: $enableCoach)
                    .tint(Theme.balanceAccent)
                Text("If on, a small model (~780 MB) downloads once and runs locally. " +
                     "You can change this anytime in Settings. The app works fully without it — " +
                     "scoring and coaching are always available via the built-in rule-based coach.")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.secondaryText(scheme))

                CardView {
                    Label("Private by design", systemImage: "lock.shield")
                        .font(Theme.body(14, weight: .semibold))
                        .foregroundStyle(Theme.balanceAccent)
                    Text("Your check-ins live only on your devices and your private iCloud database. " +
                         "We run no server.")
                        .font(Theme.body(13))
                        .foregroundStyle(Theme.secondaryText(scheme))
                        .padding(.top, 4)
                }
            }
        }
    }

    // MARK: - Scaffold + footer

    private func stepScaffold<Content: View>(title: String, subtitle: String,
                                             @ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(Theme.display(30, weight: .bold))
                    .foregroundStyle(Theme.primaryText(scheme))
                Text(subtitle)
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.secondaryText(scheme))
                content()
                    .padding(.top, 8)
            }
            .padding(24)
        }
    }

    private var footer: some View {
        HStack {
            if step > 0 {
                Button("Back") { withAnimation { step -= 1 } }
                    .foregroundStyle(Theme.secondaryText(scheme))
            }
            Spacer()
            PrimaryButton(title: step == totalSteps - 1 ? "Begin" : "Next",
                          systemImage: step == totalSteps - 1 ? "checkmark" : "arrow.right") {
                if step < totalSteps - 1 {
                    withAnimation { step += 1 }
                } else {
                    finish()
                }
            }
            .frame(maxWidth: 200)
        }
        .padding()
    }

    private func placeholder(for energy: Energy) -> String {
        switch energy {
        case .physical:  return "e.g. lights out by 11pm; a 15-min morning walk"
        case .emotional: return "e.g. one gratitude note before bed"
        case .mental:    return "e.g. one phone-free 90-min focus block"
        case .spiritual: return "e.g. 5 quiet minutes on what matters"
        }
    }

    private func finish() {
        let profile = store.ensureProfile()
        profile.purpose = purpose
        profile.goalPhysical = goals[.physical] ?? ""
        profile.goalEmotional = goals[.emotional] ?? ""
        profile.goalMental = goals[.mental] ?? ""
        profile.goalSpiritual = goals[.spiritual] ?? ""
        profile.coachEnabled = enableCoach
        profile.preferredModelID = enableCoach ? ModelCatalog.defaultModelID : nil
        try? store.context.save()
        onComplete()
    }
}
