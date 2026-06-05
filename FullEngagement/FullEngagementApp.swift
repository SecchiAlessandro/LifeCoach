import SwiftUI
import SwiftData

@main
struct FullEngagementApp: App {
    let container: ModelContainer

    init() {
        container = Self.makeContainer()
        Self.bootstrapCoach()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
        }
    }

    // MARK: - Container (SwiftData + CloudKit)

    /// Builds the SwiftData container.
    ///
    /// Currently **local-only** (Section 2). CloudKit sync is intentionally
    /// disabled until the app ships with a real iCloud container registered to a
    /// paid Apple Developer team. To re-enable: add the iCloud + CloudKit
    /// capability (entitlements with `com.apple.developer.icloud-services` =
    /// `[CloudKit]`, matching container identifiers, and `aps-environment`),
    /// add the `remote-notification` background mode, then pass
    /// `cloudKitDatabase: .private("iCloud.<your.container.id>")` to the
    /// preferred `ModelConfiguration` below. Falls back to in-memory if disk
    /// init fails, so the app always launches.
    private static func makeContainer() -> ModelContainer {
        let schema = Schema([UserProfile.self, EnergyEntry.self, Ritual.self])

        // Preferred: persistent local store.
        let localConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        if let container = try? ModelContainer(for: schema, configurations: [localConfig]) {
            return container
        }

        // Last resort: in-memory (keeps the app usable even if disk init fails).
        let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        // swiftlint:disable:next force_try
        return try! ModelContainer(for: schema, configurations: [memoryConfig])
    }

    // MARK: - Coach bootstrap

    /// Kicks off RunAnywhere runtime registration + init off the main actor.
    /// No-op until the package is added.
    private static func bootstrapCoach() {
        #if canImport(RunAnywhere)
        Task.detached(priority: .background) {
            await ModelManager.shared.bootstrapIfNeeded()
        }
        #endif
    }
}

/// Routes between onboarding and the main TabView, and wires up `EnergyStore`.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @State private var store: EnergyStore?
    @State private var didOnboard = false

    var body: some View {
        Group {
            if let store {
                if didOnboard || store.hasCompletedOnboarding {
                    MainTabView(store: store)
                } else {
                    SetupView(store: store) { didOnboard = true }
                }
            } else {
                Color.clear
            }
        }
        .onAppear {
            if store == nil {
                let s = EnergyStore(context: context)
                s.seedMockDataIfEmpty()   // Milestone 1/2: mock data for the wheel & charts
                store = s
                didOnboard = s.hasCompletedOnboarding
            }
        }
    }
}

/// The three-tab shell (Section 6): Today · History · Settings.
struct MainTabView: View {
    let store: EnergyStore

    var body: some View {
        TabView {
            DashboardView(store: store)
                .tabItem { Label("Today", systemImage: "circle.grid.cross") }
            HistoryView(store: store)
                .tabItem { Label("History", systemImage: "chart.xyaxis.line") }
            SettingsView(store: store)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(Theme.balanceAccent)
    }
}
