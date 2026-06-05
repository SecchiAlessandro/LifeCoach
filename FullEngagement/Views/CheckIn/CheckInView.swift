import SwiftUI
import SwiftData

/// The daily check-in (Section 6.3): 5–6 slider questions + optional note, then
/// deterministic scoring → coach → upsert today's entry.
struct CheckInView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    let store: EnergyStore

    @State private var questions: [CheckInQuestion] = []
    @State private var answers: [String: Double] = [:]   // 0…10
    @State private var note: String = ""
    @State private var isLoadingQuestions = true
    @State private var isScoring = false

    private var profile: UserProfile? { store.currentProfile() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("How is your energy today?")
                        .font(Theme.display(26, weight: .bold))
                        .foregroundStyle(Theme.primaryText(scheme))

                    if isLoadingQuestions {
                        ProgressView("Preparing your questions…")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else {
                        ForEach(questions) { q in
                            questionRow(q)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Note (optional)")
                                .font(Theme.body(13, weight: .bold))
                                .foregroundStyle(Theme.secondaryText(scheme))
                            TextField("Anything worth remembering about today…",
                                      text: $note, axis: .vertical)
                                .lineLimit(2...4)
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 12)
                                    .fill(Theme.surface(scheme)))
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.background(scheme).ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: isScoring ? "Scoring…" : "See my energy",
                              systemImage: "wand.and.stars") {
                    Task { await submit() }
                }
                .padding(16)
                .background(.ultraThinMaterial)
                .disabled(isLoadingQuestions || isScoring)
            }
            .navigationTitle("Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task { await loadQuestions() }
    }

    // MARK: - Question row

    private func questionRow(_ q: CheckInQuestion) -> some View {
        let binding = Binding<Double>(
            get: { answers[q.id] ?? 5 },
            set: { answers[q.id] = $0 }
        )
        let tint = q.energyEnum.map { Theme.color(for: $0) } ?? Theme.balanceAccent
        return VStack(alignment: .leading, spacing: 10) {
            Text(q.text)
                .font(Theme.body(16, weight: .medium))
                .foregroundStyle(Theme.primaryText(scheme))

            Slider(value: binding, in: 0...10, step: 1)
                .tint(tint)

            HStack {
                Text(q.lowLabel)
                Spacer()
                Text("\(Int(binding.wrappedValue))")
                    .font(Theme.body(13, weight: .bold))
                    .foregroundStyle(tint)
                Spacer()
                Text(q.highLabel)
            }
            .font(Theme.body(12))
            .foregroundStyle(Theme.secondaryText(scheme))
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.surface(scheme)))
    }

    // MARK: - Actions

    private func loadQuestions() async {
        let coach = CoachFactory.make(coachEnabled: profile?.coachEnabled ?? false,
                                      modelID: profile?.preferredModelID)
        let recent = store.recentEntries(limit: 14)
        let qs = await coach.dailyQuestions(profile: profile, recent: recent)
        await MainActor.run {
            questions = qs
            for q in qs where answers[q.id] == nil { answers[q.id] = 5 }
            isLoadingQuestions = false
        }
    }

    private func submit() async {
        isScoring = true
        // Deterministic scoring (Section 7) — never delegated to the model.
        let rawAnswers = answers.mapValues { Int($0) }
        let scores = Scoring.scores(from: rawAnswers)

        let coach = CoachFactory.make(coachEnabled: profile?.coachEnabled ?? false,
                                      modelID: profile?.preferredModelID)
        let result = await coach.coaching(profile: profile, scores: scores,
                                          bottleneck: scores.bottleneck.rawValue,
                                          balance: scores.balance)

        await MainActor.run {
            store.upsert(scores: scores,
                         coaching: result.coaching,
                         ritualNudge: result.ritualNudge,
                         rawAnswers: rawAnswers,
                         note: note.isEmpty ? nil : note)
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
            isScoring = false
            dismiss()
        }
    }
}
