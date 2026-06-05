# Full Engagement — iOS

A native SwiftUI app for daily personal **energy management**, grounded in Loehr & Schwartz's
*The Power of Full Engagement*. Daily ~2-minute check-in → four energies (Physical, Emotional,
Mental, Spiritual) on a single **energy wheel** → warm, balance-focused coaching.

Everything is on-device + private CloudKit. The optional on-device AI coach only *enhances*
prose; **scoring is always deterministic** and the app is fully functional without any model.

---

## What's in this folder

Pure Swift source, organized exactly per the spec (Section 12). There is **no `.xcodeproj` yet** —
you create one in Xcode and drop these files in (steps below). All code targets **iOS 17+**.

```
FullEngagement/
├── FullEngagementApp.swift      # @main, SwiftData+CloudKit container, coach bootstrap, root nav
├── Models/                      # UserProfile, EnergyEntry, Ritual, EnergyDomain (enum/scores/bank)
├── Store/EnergyStore.swift      # SwiftData queries, upsert-today, mock seed, JSON/CSV export
├── Coach/                       # CoachService protocol + factory, RuleBasedCoach, OnDeviceCoach
├── Views/                       # Onboarding, Today (wheel), CheckIn, History (charts), Settings
├── DesignSystem/                # Theme tokens + reusable components
└── Resources/                   # entitlements + ModelConfig.plist (reference)
```

## Build status by milestone

| Milestone | State |
|---|---|
| 1 Skeleton + data (SwiftData/CloudKit, store, mock seed, TabView) | ✅ implemented |
| 2 Energy Wheel (animated radial fill, center arrows, tap-to-detail) | ✅ implemented |
| 3 Setup + Check-in + deterministic scoring + RuleBasedCoach | ✅ implemented |
| 4 History (Swift Charts trends + range toggle) + JSON/CSV export | ✅ implemented |
| 5 On-device coach (RunAnywhere) | ⚙️ code present, **gated** on adding the package |
| 6 Polish (rituals/streaks, haptics, a11y labels, empty states) | ◐ partial (rituals model + streaks UI, haptics, VoiceOver on wheel) |

The on-device coach (`Coach/OnDeviceCoach.swift` + the `ModelDownloadProgress` view) is wrapped in
`#if canImport(RunAnywhere)`, so **the project builds and runs on the rule-based path before you add
the package.** No stubs to delete.

---

## Create the Xcode project (one-time)

1. **Xcode ▸ New ▸ Project ▸ iOS ▸ App.**
   - Product Name: `FullEngagement`
   - Interface: **SwiftUI**, Language: **Swift**, Storage: **None** (we configure SwiftData in code)
   - Minimum Deployments: **iOS 17.0**
2. **Delete** the auto-generated `ContentView.swift` and the generated `FullEngagementApp.swift`
   (we provide our own).
3. **Drag the `FullEngagement/` source folders** from this directory into the Xcode project
   navigator → check *"Copy items if needed"* and *"Create groups."* Add `Models/`, `Store/`,
   `Coach/`, `Views/`, `DesignSystem/`. Add the `FullEngagementApp.swift` at the target root.
4. Build & run on an **iPhone 15 / iOS 17+ simulator**. It launches into onboarding, then the wheel
   (seeded with ~3 weeks of mock data so charts have something to show).

> Mock seeding lives in `EnergyStore.seedMockDataIfEmpty()`, called from `RootView`. Remove that
> call before shipping if you don't want demo data.

## Enable iCloud sync (Milestone 1 acceptance)

1. Target ▸ **Signing & Capabilities** ▸ **+ Capability** ▸ **iCloud** → check **CloudKit**, add a
   container, e.g. `iCloud.com.yourorg.fullengagement`.
2. Add **Background Modes** ▸ check **Remote notifications** (for push sync).
3. Make the container ID match the string in
   `FullEngagementApp.swift › makeContainer()` (`cloudKitDatabase: .private("iCloud.com.yourorg.fullengagement")`).
   `Resources/FullEngagement.entitlements` is a reference for the generated entitlements.
4. If CloudKit isn't set up yet, the app **automatically falls back to a local store** so it still
   runs. To verify sync: run on two simulators signed into the **same iCloud account** and confirm a
   check-in on one appears on the other.

## Enable the on-device AI coach (Milestone 5)

1. **File ▸ Add Package Dependencies…**
   URL: `https://github.com/RunanywhereAI/runanywhere-sdks`
   Pin a recent release (**≥ v0.19.x** — check the Releases page).
   Add products: **`RunAnywhere`** and a runtime, e.g. **`LlamaCPPRuntime`**.
2. Build. `OnDeviceCoach.swift` and the download UI activate automatically via `canImport`.
3. ⚠️ **Verify SDK call sites.** The lines marked `RUNANYWHERE API` in `OnDeviceCoach.swift`
   (`RunAnywhere.initialize()`, `loadModel`, `unloadModel`, `chat`) follow the spec's shape but
   **must be checked against the current SDK README** (`sdk/runanywhere-swift/`) and the
   `swift-starter-example`. Adjust signatures + wire real download-progress into
   `ModelManager.State.downloading(progress:)`.
4. Toggle the coach on in onboarding or **Settings ▸ Coaching**; pick/swap the model there too.

## Design / fonts

Display type uses the system serif (**New York**) so nothing needs bundling. To switch to
**Fraunces**, add the `.ttf`s to the target, list them under `Info.plist › Fonts provided by
application`, and change `Theme.display(...)` to `.custom("Fraunces", size:)`.

Colors, the four-quadrant hues, light/dark backgrounds, and the balance accent are all in
`DesignSystem/Theme.swift` (Section 11 tokens).

## Privacy & licensing (App Store)

- All check-in data stays on device + the user's **private** CloudKit DB. No server.
- On-device inference: prompts/responses never leave the phone.
- Declare the one-time model download (size) and that AI runs on-device.
- Bundle/note model licenses (Llama → Meta license; Qwen → Apache-2.0). RunAnywhere SDK is Apache-2.0.

## Acceptance checklist (Section 15)

- [x] Works end-to-end with the coach **off** (rule-based). [ ] With it **on** — verify after adding the package.
- [x] Scoring deterministic & identical regardless of coach mode (`Scoring` in `EnergyDomain.swift`).
- [x] Wheel fills per quadrant by % and animates on change; center arrows reflect recovery.
- [x] Balance is the headline metric; coaching targets the weakest energy + pyramid logic when physical is the floor.
- [ ] iCloud sync across devices + survives reinstall — verify after enabling CloudKit.
- [x] One-tap JSON **and** CSV export via `ShareLink` (Settings).
```
