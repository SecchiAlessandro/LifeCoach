import SwiftUI

/// The signature UI (Section 5): one circle, four quadrants filling radially
/// from the center, plus a center hub with oscillation arrows reflecting the
/// recovery score. Tapping a quadrant calls `onSelect`.
struct EnergyWheel: View {
    /// 0…100 per energy.
    var scores: EnergyScores
    var onSelect: (Energy) -> Void

    /// Staggered appear animation: per-quadrant fill is multiplied by this gate.
    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let rect = CGRect(x: (geo.size.width - side) / 2,
                              y: (geo.size.height - side) / 2,
                              width: side, height: side)

            ZStack {
                // Quadrant tracks + fills + labels.
                ForEach(Energy.allCases) { energy in
                    quadrant(energy, in: rect, side: side)
                }

                // Dividing lines for crispness.
                divider(rect: rect, vertical: true)
                divider(rect: rect, vertical: false)

                // Center hub with oscillation arrows.
                CenterHub(recovery: scores.recovery, balance: scores.balance)
                    .frame(width: side * 0.26, height: side * 0.26)
                    .position(x: rect.midX, y: rect.midY)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
            withAnimation(.spring(duration: 1.0)) { appeared = true }
        }
    }

    // MARK: - Pieces

    @ViewBuilder
    private func quadrant(_ energy: Energy, in rect: CGRect, side: CGFloat) -> some View {
        let (start, end) = energy.quadrantAngles
        let color = Theme.color(for: energy)
        let target = appeared ? Double(scores[energy]) : 0

        ZStack {
            // Faint full-quadrant track (100% boundary).
            QuadrantShape(startAngle: start, endAngle: end, pct: 100, isTrack: true)
                .fill(color.opacity(0.16))

            // Radial fill, animated on pct.
            QuadrantShape(startAngle: start, endAngle: end, pct: target, isTrack: false)
                .fill(
                    LinearGradient(colors: [color.opacity(0.95), color.opacity(0.75)],
                                   startPoint: .center, endPoint: .topTrailing)
                )
                .animation(.spring(duration: 1.0), value: target)
        }
        .contentShape(QuadrantShape(startAngle: start, endAngle: end, pct: 100, isTrack: true))
        .onTapGesture { onSelect(energy) }
        // Label at the quadrant's angular midpoint, ~62% out.
        .overlay(label(energy, in: rect, side: side))
        .accessibilityElement()
        .accessibilityLabel("\(energy.title) energy")
        .accessibilityValue("\(scores[energy]) percent")
        .accessibilityHint("Opens \(energy.title) detail")
        .accessibilityAddTraits(.isButton)
    }

    private func label(_ energy: Energy, in rect: CGRect, side: CGFloat) -> some View {
        let dir = energy.labelDirection
        let radius = side * 0.31
        let pos = CGPoint(x: rect.midX + dir.x * radius,
                          y: rect.midY + dir.y * radius)
        return VStack(spacing: 2) {
            Text(energy.title.uppercased())
                .font(Theme.body(13, weight: .bold))
                .tracking(0.5)
            Text("\(scores[energy])")
                .font(Theme.display(20, weight: .semibold))
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
        .position(pos)
        .allowsHitTesting(false)
    }

    private func divider(rect: CGRect, vertical: Bool) -> some View {
        Path { p in
            if vertical {
                p.move(to: CGPoint(x: rect.midX, y: rect.minY))
                p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            } else {
                p.move(to: CGPoint(x: rect.minX, y: rect.midY))
                p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            }
        }
        .stroke(.white.opacity(0.22), lineWidth: 1.5)
        .allowsHitTesting(false)
    }
}

/// Center hub: two curved oscillation arrows whose crispness reflects recovery,
/// with the balance score in the middle.
struct CenterHub: View {
    @Environment(\.colorScheme) private var scheme
    var recovery: Int   // 0…100
    var balance: Int    // 0…100

    @State private var spin = false

    private var clarity: Double { 0.3 + 0.7 * (Double(recovery) / 100.0) }

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.surface(scheme))
                .shadow(color: .black.opacity(0.2), radius: 8, y: 3)

            Image(systemName: "arrow.triangle.2.circlepath")
                .resizable()
                .scaledToFit()
                .padding(10)
                .foregroundStyle(Theme.centerArrows)
                .opacity(clarity)
                .rotationEffect(.degrees(spin ? 360 : 0))
                .animation(
                    recovery > 60
                        ? .linear(duration: 8).repeatForever(autoreverses: false)
                        : .default,
                    value: spin
                )

            VStack(spacing: 0) {
                Text("\(balance)")
                    .font(Theme.display(22, weight: .bold))
                    .foregroundStyle(Theme.primaryText(scheme))
                Text("balance")
                    .font(Theme.body(9, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText(scheme))
            }
        }
        .onAppear { if recovery > 60 { spin = true } }
        .accessibilityElement()
        .accessibilityLabel("Recovery \(recovery) percent, balance \(balance)")
    }
}
