import Foundation
import SwiftData

/// Single profile per user, created on first launch.
///
/// All properties have defaults so the model is CloudKit-compatible
/// (CloudKit-backed SwiftData requires non-optional attributes to have
/// default values).
@Model
final class UserProfile {
    var purpose: String = "Is the life I am living worth what I'm giving up to have it?"
    var goalPhysical: String = ""
    var goalEmotional: String = ""
    var goalMental: String = ""
    var goalSpiritual: String = ""
    var createdAt: Date = Date()
    var preferredModelID: String?            // swappable on-device model
    var coachEnabled: Bool = false           // on-device AI on/off (off until model downloaded)

    init(purpose: String = "Is the life I am living worth what I'm giving up to have it?",
         goalPhysical: String = "",
         goalEmotional: String = "",
         goalMental: String = "",
         goalSpiritual: String = "",
         createdAt: Date = Date(),
         preferredModelID: String? = nil,
         coachEnabled: Bool = false) {
        self.purpose = purpose
        self.goalPhysical = goalPhysical
        self.goalEmotional = goalEmotional
        self.goalMental = goalMental
        self.goalSpiritual = goalSpiritual
        self.createdAt = createdAt
        self.preferredModelID = preferredModelID
        self.coachEnabled = coachEnabled
    }

    func goal(for energy: Energy) -> String {
        switch energy {
        case .physical:  return goalPhysical
        case .emotional: return goalEmotional
        case .mental:    return goalMental
        case .spiritual: return goalSpiritual
        }
    }

    var goalsSummary: String {
        Energy.allCases
            .map { "\($0.title): \(goal(for: $0).isEmpty ? "—" : goal(for: $0))" }
            .joined(separator: "; ")
    }
}
