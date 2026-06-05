import SwiftUI

/// Design tokens (Section 11). Colors, typography, and per-energy hues.
enum Theme {

    // MARK: - Energy colors

    static func color(for energy: Energy) -> Color {
        switch energy {
        case .physical:  return Color(hex: 0xB25750) // dusty terracotta red — top-left
        case .mental:    return Color(hex: 0x8FB05A) // sage green          — top-right
        case .emotional: return Color(hex: 0x4F96B5) // teal blue           — bottom-left
        case .spiritual: return Color(hex: 0x7E5FA8) // muted violet        — bottom-right
        }
    }

    static let centerArrows = Color(hex: 0xE6E2DE)   // warm light gray
    static let balanceAccent = Color(hex: 0x43D6B5)  // teal

    // MARK: - Backgrounds

    static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x121110) : Color(hex: 0xF6F3EE)
    }

    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x1E1C1A) : Color.white
    }

    static func primaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xF6F3EE) : Color(hex: 0x201E1B)
    }

    static func secondaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xB8B2AA) : Color(hex: 0x6B655D)
    }

    // MARK: - Typography
    //
    // Uses the system serif (New York) for display numbers/headers to avoid
    // bundling fonts. To use Fraunces instead, add the .ttf to the target and
    // swap `.system(... design: .serif)` for `.custom("Fraunces", size:)`.

    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

// MARK: - Color hex init

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8)  & 0xFF) / 255.0,
            blue:  Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
