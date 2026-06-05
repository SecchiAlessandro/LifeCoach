import Foundation

// MARK: - On-device coach (Milestone 5)
//
// This whole file is gated on `canImport(RunAnywhere)` so the app compiles and
// runs fully on the rule-based path BEFORE you add the package. To enable:
//
//   1. In Xcode: File ▸ Add Package Dependencies…
//      URL: https://github.com/RunanywhereAI/runanywhere-sdks
//      Pin a recent release (≥ v0.19.x — check the releases page).
//      Add products: `RunAnywhere` and a runtime, e.g. `LlamaCPPRuntime`.
//   2. Build. This file activates automatically.
//
// ⚠️ The calls marked `RUNANYWHERE API` below follow the shape in Section 8 of
//    the spec. Verify exact signatures against the SDK README at
//    `sdk/runanywhere-swift/` and the swift-starter-example before shipping —
//    do not assume they are correct as-written.

#if canImport(RunAnywhere)
import RunAnywhere
#if canImport(LlamaCPPRuntime)
import LlamaCPPRuntime
#endif

/// Manages one RunAnywhere model: registration, init, on-demand download/load,
/// and unload when switching models. Lives for the app's lifetime.
@Observable
@MainActor
final class ModelManager {
    enum State: Equatable {
        case idle
        case downloading(progress: Double)
        case loading
        case ready
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var loadedModelID: String?

    static let shared = ModelManager()
    private var didInitRuntime = false

    /// One-time runtime registration + offline init. Safe to call repeatedly.
    func bootstrapIfNeeded() async {
        guard !didInitRuntime else { return }
        // RUNANYWHERE API — register runtime + initialize (offline / on-device).
        #if canImport(LlamaCPPRuntime)
        LlamaCPP.register()
        #endif
        do {
            // `.development` runs fully on-device/offline — no API key or base URL.
            try RunAnywhere.initialize(environment: .development)
            didInitRuntime = true
        } catch {
            state = .failed("Init failed: \(error.localizedDescription)")
        }
    }

    /// Downloads (first run) + loads a model, reporting progress. Idempotent
    /// for an already-loaded model.
    func ensureLoaded(modelID: String) async {
        await bootstrapIfNeeded()
        guard didInitRuntime else { return }

        // Resolve through the catalog so a stale/persisted ID maps to a valid
        // entry (and gives us the download URL).
        let option = ModelCatalog.option(for: modelID)
        let realID = option.id
        if loadedModelID == realID, case .ready = state { return }

        if let previous = loadedModelID, previous != realID {
            await unload()
        }

        state = .downloading(progress: 0)
        do {
            // Offline/dev mode ships no LLM catalog, so register the model from
            // its direct GGUF URL, then wait for the async registry save.
            RunAnywhere.registerModel(id: realID,
                                      name: option.displayName,
                                      urlString: option.url,
                                      framework: .llamaCpp,
                                      modality: .language,
                                      artifactType: .singleFile())
            await RunAnywhere.flushPendingRegistrations()

            // First run downloads the GGUF weights; the (non-throwing) stream
            // reports byte progress, which we surface to the download UI.
            let progress = try await RunAnywhere.downloadModel(realID)
            for await update in progress where update.totalBytes > 0 {
                state = .downloading(progress: Double(update.bytesDownloaded) / Double(update.totalBytes))
            }
            state = .loading
            try await RunAnywhere.loadModel(realID)
            loadedModelID = realID
            state = .ready
        } catch {
            state = .failed("Model load failed: \(error.localizedDescription)")
        }
    }

    func unload() async {
        guard loadedModelID != nil else { return }
        try? await RunAnywhere.unloadModel()
        loadedModelID = nil
        state = .idle
    }

    var isReady: Bool { if case .ready = state { return true }; return false }

    /// Runs a chat completion. Returns nil on any failure so callers can fall
    /// through to the rule-based path. Timeout is generous because simulator
    /// inference (CPU-bound) is much slower than on a real device.
    func complete(system: String, user: String, timeout: TimeInterval = 25) async -> String? {
        guard isReady else { return nil }
        // Pass the system prompt SEPARATELY: the C++ runtime applies the model's
        // chat template (ChatML) to [system, user] messages. Folding everything
        // into one bare `chat()` string skips the template, so the model runs
        // unconditioned and degenerates (e.g. "<jupyter_start>////").
        // Default maxTokens is only 100 — too short for coaching prose.
        let options = LLMGenerationOptions(maxTokens: 256,
                                           temperature: 0.7,
                                           topP: 0.9,
                                           systemPrompt: system)
        return await withTimeout(seconds: timeout) {
            try? await RunAnywhere.generate(user, options: options).text
        }
    }
}

/// Enhances coaching prose and lightly personalizes question wording using the
/// on-device model. Always falls back to `RuleBasedCoach` on any failure.
struct OnDeviceCoach: CoachService {
    let modelID: String
    let fallback: RuleBasedCoach

    func dailyQuestions(profile: UserProfile?, recent: [EnergyEntry]) async -> [CheckInQuestion] {
        let bank = QuestionBank.dailySet(recent: recent)
        await ModelManager.shared.ensureLoaded(modelID: modelID)
        guard ModelManager.shared.isReady else { return bank }

        // Ask the model to rephrase each question in ≤20 words. Any malformed
        // or empty line → keep the bank verbatim for that question.
        var personalized: [CheckInQuestion] = []
        for q in bank {
            let prompt = "Rephrase this check-in question in a warm, plain tone, " +
                         "20 words max, keep the same meaning, no quotes:\n\(q.text)"
            if let raw = await ModelManager.shared.complete(
                system: "You rephrase survey questions. Output only the question.",
                user: prompt, timeout: 20),
               let cleaned = Self.sanitizeQuestion(raw) {
                var copy = q
                copy.text = cleaned
                personalized.append(copy)
            } else {
                personalized.append(q)
            }
        }
        return personalized
    }

    func coaching(profile: UserProfile?,
                  scores: EnergyScores,
                  bottleneck: String,
                  balance: Int) async -> (coaching: String, ritualNudge: String) {
        let fb = fallback.coachingSync(profile: profile, scores: scores,
                                       bottleneck: bottleneck, balance: balance)
        await ModelManager.shared.ensureLoaded(modelID: modelID)
        guard ModelManager.shared.isReady else { return fb }

        let weakest = Energy(rawValue: bottleneck) ?? scores.bottleneck
        let system = Self.systemPrompt
        let user = Self.userPrompt(profile: profile, scores: scores,
                                   bottleneck: weakest, balance: balance)

        guard let raw = await ModelManager.shared.complete(system: system, user: user),
              let prose = Self.sanitizeCoaching(raw)
        else { return fb }

        // The model writes prose; the deterministic nudge from the fallback is
        // a reliable ritual-shaped close. (You can also have the model produce
        // the nudge and parse it; the fallback keeps it safe.)
        return (prose, fb.ritualNudge)
    }

    // MARK: - Prompt building (Section 8)

    static let systemPrompt =
        """
        You are an energy-management coach (Loehr & Schwartz, "Full Engagement").
        Four energies form a pyramid: physical is the foundation; a weak physical floor caps the rest.
        The user's priority is BALANCE — close the gap between strongest and weakest.
        Be warm, concrete, 3 sentences max. End with ONE ritual-shaped nudge for the weakest energy.
        """

    static func userPrompt(profile: UserProfile?, scores: EnergyScores,
                           bottleneck: Energy, balance: Int) -> String {
        let purpose = profile?.purpose ?? "—"
        let goals = profile?.goalsSummary ?? "—"
        return """
        Purpose: \(purpose)
        Goals: \(goals)
        Today's scores (0-100): physical \(scores.physical), emotional \(scores.emotional), \
        mental \(scores.mental), spiritual \(scores.spiritual); balance \(balance).
        Weakest: \(bottleneck.title).
        Write the coaching now.
        """
    }

    // MARK: - Output sanitation

    static func sanitizeQuestion(_ raw: String) -> String? {
        let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines).first?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) ?? ""
        let words = line.split(separator: " ").count
        guard words >= 3, words <= 24, line.count <= 160 else { return nil }
        return line
    }

    static func sanitizeCoaching(_ raw: String) -> String? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 20, text.count <= 600 else { return nil }
        return text
    }
}

// MARK: - Timeout helper

func withTimeout<T>(seconds: TimeInterval, _ operation: @escaping () async -> T?) async -> T? {
    await withTaskGroup(of: T?.self) { group in
        group.addTask { await operation() }
        group.addTask {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return nil
        }
        let result = await group.next() ?? nil
        group.cancelAll()
        return result
    }
}

#endif
