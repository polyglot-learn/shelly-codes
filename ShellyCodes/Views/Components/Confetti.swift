import SwiftUI

/// A burst of confetti for finishing a level. Respects Reduce Motion.
struct Confetti: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now
    private let pieces: [Piece] = (0..<90).map { _ in Piece() }

    struct Piece {
        let x = Double.random(in: 0...1)
        let delay = Double.random(in: 0...0.6)
        let speed = Double.random(in: 0.35...0.7)
        let drift = Double.random(in: -0.15...0.15)
        let spin = Double.random(in: 2...8)
        let size = Double.random(in: 8...16)
        let color = [0x2FBF71, 0x3D8BFD, 0xFF9F1C, 0xE5468C, 0x8E5CF7, 0xF5C518].randomElement()!
    }

    var body: some View {
        if reduceMotion {
            EmptyView()
        } else {
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let t = timeline.date.timeIntervalSince(start)
                    for piece in pieces {
                        let age = t - piece.delay
                        guard age > 0 else { continue }
                        let y = -0.05 + age * piece.speed
                        guard y < 1.1 else { continue }
                        let x = piece.x + piece.drift * sin(age * 3)
                        var ctx = context
                        ctx.translateBy(x: x * size.width, y: y * size.height)
                        ctx.rotate(by: .radians(age * piece.spin))
                        ctx.fill(
                            Path(CGRect(x: -piece.size / 2, y: -piece.size / 4, width: piece.size, height: piece.size / 2)),
                            with: .color(Color(hex: UInt32(piece.color)))
                        )
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

#Preview {
    Confetti()
}
