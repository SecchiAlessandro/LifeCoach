import Foundation

/// Coaching abstraction (Section 8). Scoring is NEVER delegated here — the
/// caller computes `EnergyScores` deterministically and passes them in.
///
/// Main-actor isolated: implementations receive main-actor-bound SwiftData
/// models (`UserProfile`, `EnergyEntry`), so requirements run on the main actor
/// to avoid sending non-Sendable values across isolation boundaries.
@MainActor
protocol CoachService {
    /// May lightly personalize wording; falls back to the bank verbatim on failure.
    func dailyQuestions(profile: UserProfile?, recent: [EnergyEntry]) async -> [CheckInQuestion]

    /// Returns ONLY prose + nudge.
    func coaching(profile: UserProfile?,
                  scores: EnergyScores,
                  bottleneck: String,
                  balance: Int) async -> (coaching: String, ritualNudge: String)
}

/// Builds the appropriate coach. The app is always fully functional with the
/// rule-based coach; the on-device coach only *enhances* prose when available
/// and enabled.
enum CoachFactory {
    static func make(coachEnabled: Bool, modelID: String?) -> CoachService {
        #if canImport(RunAnywhere)
        if coachEnabled {
            return OnDeviceCoach(modelID: modelID ?? ModelCatalog.defaultModelID,
                                 fallback: RuleBasedCoach())
        }
        #endif
        return RuleBasedCoach()
    }
}

/// Swappable model configuration (Section 2 — kept in one place).
enum ModelCatalog {
    struct ModelOption: Identifiable, Hashable {
        let id: String          // our stable identifier (also the registry ID)
        let displayName: String
        let approxSizeMB: Int
        let license: String
        let url: String         // direct GGUF download URL (HuggingFace `resolve`)
    }

    // In offline/development mode the SDK has no remote model catalog, so we
    // register each model from its direct GGUF URL ourselves (see
    // `OnDeviceCoach.ModelManager.ensureLoaded`). Small instruct models first —
    // the iOS Simulator is CPU-bound, so a 0.5B/360M model stays responsive.
    static let options: [ModelOption] = [
        .init(id: "smollm2-360m-instruct-q4_k_m",
              displayName: "SmolLM2 360M Instruct (Q4)",
              approxSizeMB: 270, license: "Apache-2.0",
              url: "https://huggingface.co/unsloth/SmolLM2-360M-Instruct-GGUF/resolve/main/SmolLM2-360M-Instruct-Q4_K_M.gguf"),
        .init(id: "qwen2.5-0.5b-instruct-q4_k_m",
              displayName: "Qwen2.5 0.5B Instruct (Q4)",
              approxSizeMB: 400, license: "Apache-2.0",
              url: "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf"),
    ]

    static let defaultModelID = options[0].id

    static func option(for id: String?) -> ModelOption {
        options.first { $0.id == id } ?? options[0]
    }
}
