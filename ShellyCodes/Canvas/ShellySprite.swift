import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    init(rgb: RGB) {
        self.init(.sRGB, red: rgb.r, green: rgb.g, blue: rgb.b)
    }

    static let paper = Color(hex: 0xFFFCF2)
    static let skin = Color(hex: 0x9BD770)
    static let skinDark = Color(hex: 0x5E9E3A)
}

/// Draws Shelly the turtle, facing right before rotation. `size` is her length from tail to nose.
enum ShellySprite {
    static func draw(in context: GraphicsContext, at center: CGPoint, heading: Double, size: CGFloat, shell: Shell) {
        var ctx = context
        ctx.translateBy(x: center.x, y: center.y)
        // Canvas y points down, so a counterclockwise heading is a negative rotation.
        ctx.rotate(by: .degrees(-heading))
        let s = size

        func ellipse(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path {
            Path(ellipseIn: CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h))
        }

        // Legs
        for (x, y) in [(0.2, -0.28), (0.2, 0.28), (-0.22, -0.26), (-0.22, 0.26)] {
            let leg = ellipse(x * s, y * s, 0.2 * s, 0.17 * s)
            ctx.fill(leg, with: .color(.skin))
            ctx.stroke(leg, with: .color(.skinDark), lineWidth: 0.025 * s)
        }
        // Tail
        var tail = Path()
        tail.move(to: CGPoint(x: -0.32 * s, y: -0.06 * s))
        tail.addLine(to: CGPoint(x: -0.5 * s, y: 0))
        tail.addLine(to: CGPoint(x: -0.32 * s, y: 0.06 * s))
        tail.closeSubpath()
        ctx.fill(tail, with: .color(.skin))
        ctx.stroke(tail, with: .color(.skinDark), lineWidth: 0.025 * s)
        // Head
        let head = ellipse(0.4 * s, 0, 0.27 * s, 0.24 * s)
        ctx.fill(head, with: .color(.skin))
        ctx.stroke(head, with: .color(.skinDark), lineWidth: 0.025 * s)
        for y in [-0.06, 0.06] {
            ctx.fill(ellipse(0.46 * s, y * s, 0.07 * s, 0.07 * s), with: .color(.white))
            ctx.fill(ellipse(0.475 * s, y * s, 0.04 * s, 0.04 * s), with: .color(.black))
        }
        // Shell
        let colors = shell.colors
        let body = ellipse(0, 0, 0.66 * s, 0.56 * s)
        ctx.fill(body, with: .color(Color(hex: colors.shell)))
        let inner = ellipse(0, 0, 0.36 * s, 0.3 * s)
        ctx.fill(inner, with: .color(Color(hex: colors.pattern)))
        for angle in stride(from: 0.0, to: 360.0, by: 60.0) {
            let r = angle * .pi / 180
            ctx.fill(
                ellipse(0.24 * s * cos(r), 0.2 * s * sin(r), 0.1 * s, 0.09 * s),
                with: .color(Color(hex: colors.pattern))
            )
        }
        ctx.stroke(body, with: .color(Color(hex: colors.pattern)), lineWidth: 0.035 * s)
        ctx.fill(ellipse(-0.08 * s, -0.12 * s, 0.14 * s, 0.07 * s), with: .color(.white.opacity(0.35)))
    }
}

/// Shelly on her own, for headers and the welcome screen.
struct ShellyView: View {
    var shell: Shell
    var heading: Double = 90

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            ShellySprite.draw(
                in: context, at: CGPoint(x: size.width / 2, y: size.height / 2),
                heading: heading, size: side, shell: shell
            )
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        ForEach(Shell.allCases) { shell in
            ShellyView(shell: shell).frame(width: 100, height: 100)
        }
    }
}
