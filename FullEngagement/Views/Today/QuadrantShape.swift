import SwiftUI

/// A pie wedge spanning one quadrant's 90° arc, filling radially from the
/// center outward (Section 5). Inner radius is 0; the outer radius is driven by
/// `pct` (0…100), which is the animatable property — so fill changes animate.
///
/// Angle convention: screen coordinates with y pointing down. 0° = right (+x),
/// angle increases clockwise on screen (90° = bottom, 180° = left, 270° = top).
/// This matches the spec's quadrant placement:
///   Spiritual  0–90°  → bottom-right
///   Emotional 90–180° → bottom-left
///   Physical 180–270° → top-left
///   Mental   270–360° → top-right
struct QuadrantShape: Shape {
    var startAngle: Double   // degrees
    var endAngle: Double     // degrees
    /// 0…100 — the fill percentage. Animatable.
    var pct: Double
    /// When true, draws the full 100% wedge (the faint track), ignoring pct.
    var isTrack: Bool

    var animatableData: Double {
        get { pct }
        set { pct = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let maxR = min(rect.width, rect.height) / 2
        let r = isTrack ? maxR : maxR * (max(0, min(100, pct)) / 100.0)

        var path = Path()
        guard r > 0 else { return path }

        path.move(to: center)
        let steps = 24
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let angle = (startAngle + (endAngle - startAngle) * t) * .pi / 180
            let point = CGPoint(
                x: center.x + r * cos(angle),
                y: center.y + r * sin(angle)
            )
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

/// Angle ranges per energy (screen convention above).
extension Energy {
    var quadrantAngles: (start: Double, end: Double) {
        switch self {
        case .spiritual: return (0, 90)     // bottom-right
        case .emotional: return (90, 180)   // bottom-left
        case .physical:  return (180, 270)  // top-left
        case .mental:    return (270, 360)  // top-right
        }
    }

    /// Unit-circle position (screen coords) for the label, at the quadrant's
    /// angular midpoint.
    var labelDirection: CGPoint {
        let (s, e) = quadrantAngles
        let mid = (s + e) / 2 * .pi / 180
        return CGPoint(x: cos(mid), y: sin(mid))
    }
}
