import SwiftUI

/// A crafted card surface used for the coach card, detail rows, etc.
struct CardView<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    var content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Theme.surface(scheme))
                    .shadow(color: .black.opacity(scheme == .dark ? 0.4 : 0.06),
                            radius: 14, x: 0, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Theme.primaryText(scheme).opacity(0.05), lineWidth: 1)
            )
    }
}

/// The primary call-to-action button.
struct PrimaryButton: View {
    var title: String
    var systemImage: String?
    var tint: Color = Theme.balanceAccent
    var action: () -> Void

    var body: some View {
        Button(action: {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif
            action()
        }) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).font(Theme.body(17, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(.black)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(tint)
            )
        }
        .buttonStyle(.plain)
    }
}

/// A small pill label (e.g. for the bottleneck energy).
struct PillLabel: View {
    var text: String
    var color: Color

    var body: some View {
        Text(text)
            .font(Theme.body(13, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(color.opacity(0.18)))
            .foregroundStyle(color)
    }
}

/// A section header in the characterful serif.
struct SectionHeader: View {
    @Environment(\.colorScheme) private var scheme
    var title: String

    var body: some View {
        Text(title)
            .font(Theme.display(22, weight: .semibold))
            .foregroundStyle(Theme.primaryText(scheme))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
