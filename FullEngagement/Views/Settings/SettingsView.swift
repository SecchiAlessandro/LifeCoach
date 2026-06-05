import SwiftUI
import SwiftData

/// Settings tab (Section 6.5): edit purpose & goals, toggle on-device coach,
/// pick/swap model, export data, iCloud status, privacy note.
struct SettingsView: View {
    @Environment(\.colorScheme) private var scheme
    let store: EnergyStore

    @State private var profile: UserProfile?
    @State private var showModelDownload = false

    var body: some View {
        NavigationStack {
            Form {
                purposeSection
                coachSection
                exportSection
                syncSection
                privacySection
            }
            .navigationTitle("Settings")
            .onAppear { profile = store.ensureProfile() }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var purposeSection: some View {
        if profile != nil {
            Section("Purpose") {
                TextField("Your purpose", text: bind(\.purpose), axis: .vertical)
                    .lineLimit(2...4)
            }
            Section("Ritual goals") {
                ForEach(Energy.allCases) { energy in
                    HStack {
                        Circle().fill(Theme.color(for: energy)).frame(width: 10, height: 10)
                        TextField("\(energy.title) ritual", text: goalBinding(energy))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var coachSection: some View {
        if let profile {
            Section {
                Toggle("On-device AI coach", isOn: bind(\.coachEnabled))
                    .onChange(of: profile.coachEnabled) { _, enabled in
                        if enabled { showModelDownload = true }
                    }
                if profile.coachEnabled {
                    Picker("Model", selection: modelBinding) {
                        ForEach(ModelCatalog.options) { option in
                            Text(option.displayName).tag(option.id)
                        }
                    }
                    let opt = ModelCatalog.option(for: profile.preferredModelID)
                    LabeledContent("Download size", value: "~\(opt.approxSizeMB) MB")
                    LabeledContent("License", value: opt.license)
                }
            } header: {
                Text("Coaching")
            } footer: {
                Text("When on, coaching prose and question wording are generated on-device. " +
                     "Scoring is always deterministic and identical either way. " +
                     "Prompts never leave your phone.")
            }
            .sheet(isPresented: $showModelDownload) {
                ModelDownloadView(modelID: profile.preferredModelID ?? ModelCatalog.defaultModelID)
            }
        }
    }

    private var exportSection: some View {
        Section("Export") {
            ShareLink(item: jsonFile, preview: SharePreview("FullEngagement.json")) {
                Label("Export JSON", systemImage: "square.and.arrow.up")
            }
            ShareLink(item: csvFile, preview: SharePreview("FullEngagement.csv")) {
                Label("Export CSV", systemImage: "tablecells")
            }
        }
    }

    private var syncSection: some View {
        Section {
            LabeledContent("iCloud sync") {
                Label("Private database", systemImage: "checkmark.icloud")
                    .foregroundStyle(Theme.balanceAccent)
            }
        } footer: {
            Text("Your data lives only on your devices and in your private iCloud database. " +
                 "It syncs automatically and survives reinstall. We run no server.")
        }
    }

    private var privacySection: some View {
        Section("About") {
            LabeledContent("Framework", value: "Loehr & Schwartz")
            LabeledContent("Version", value: "1.0")
        }
    }

    // MARK: - Bindings

    private func bind(_ keyPath: ReferenceWritableKeyPath<UserProfile, String>) -> Binding<String> {
        Binding(
            get: { profile?[keyPath: keyPath] ?? "" },
            set: { profile?[keyPath: keyPath] = $0; try? store.context.save() }
        )
    }

    private func bind(_ keyPath: ReferenceWritableKeyPath<UserProfile, Bool>) -> Binding<Bool> {
        Binding(
            get: { profile?[keyPath: keyPath] ?? false },
            set: { profile?[keyPath: keyPath] = $0; try? store.context.save() }
        )
    }

    private func goalBinding(_ energy: Energy) -> Binding<String> {
        switch energy {
        case .physical:  return bind(\.goalPhysical)
        case .emotional: return bind(\.goalEmotional)
        case .mental:    return bind(\.goalMental)
        case .spiritual: return bind(\.goalSpiritual)
        }
    }

    private var modelBinding: Binding<String> {
        Binding(
            get: { profile?.preferredModelID ?? ModelCatalog.defaultModelID },
            set: { profile?.preferredModelID = $0; try? store.context.save() }
        )
    }

    // MARK: - Export files

    private var jsonFile: URL { writeTemp(data: store.exportJSON(), name: "FullEngagement.json") }
    private var csvFile: URL {
        writeTemp(data: Data(store.exportCSV().utf8), name: "FullEngagement.csv")
    }

    private func writeTemp(data: Data, name: String) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? data.write(to: url)
        return url
    }
}

/// First-run model download UX (Section 5/8). On the rule-based build this just
/// explains what would happen; once RunAnywhere is added it drives the real
/// download via `ModelManager`.
struct ModelDownloadView: View {
    @Environment(\.dismiss) private var dismiss
    let modelID: String

    var body: some View {
        let opt = ModelCatalog.option(for: modelID)
        VStack(spacing: 20) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 54))
                .foregroundStyle(Theme.balanceAccent)
            Text("Download \(opt.displayName)")
                .font(Theme.display(22, weight: .bold))
                .multilineTextAlignment(.center)
            Text("A one-time ~\(opt.approxSizeMB) MB download. The model runs entirely " +
                 "on your phone — your check-ins and prompts never leave the device.")
                .font(Theme.body(15))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            #if canImport(RunAnywhere)
            ModelDownloadProgress(modelID: modelID)
            #else
            Text("Add the RunAnywhere package to enable on-device coaching " +
                 "(see OnDeviceCoach.swift). Until then the app uses the built-in " +
                 "rule-based coach.")
                .font(Theme.body(13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            #endif

            Spacer()
            PrimaryButton(title: "Done") { dismiss() }
        }
        .padding(28)
    }
}

#if canImport(RunAnywhere)
/// Drives + displays the real download progress.
struct ModelDownloadProgress: View {
    let modelID: String
    @State private var manager = ModelManager.shared

    var body: some View {
        VStack(spacing: 8) {
            switch manager.state {
            case .idle, .loading:
                ProgressView()
            case .downloading(let p):
                ProgressView(value: p) { Text("Downloading…") }
            case .ready:
                Label("Ready", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Theme.balanceAccent)
            case .failed(let msg):
                Text(msg).foregroundStyle(.red).font(.caption)
            }
        }
        .task { await manager.ensureLoaded(modelID: modelID) }
    }
}
#endif
