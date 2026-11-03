import SwiftUI

/// Draws a run up to the current moment of its replay, with the level's dotted target and stars.
struct TurtleCanvas: View {
    let events: [TurtleEvent]
    let progress: (done: Int, fraction: Double)
    let pose: Pose
    var stars: [Point] = []
    var starsCollectedAt: [Int: Int] = [:]
    var ghost: [(Point, Point)] = []
    var shell: Shell = .meadow
    var showGrid = true

    /// Canvas units visible across the shorter side.
    static let span: CGFloat = 440

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / Self.span
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            func map(_ p: Point) -> CGPoint {
                CGPoint(x: center.x + p.x * scale, y: center.y - p.y * scale)
            }
            let done = min(progress.done, events.count)

            var background = Color.paper
            for case .background(let rgb) in events.prefix(done) { background = Color(rgb: rgb) }
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(background))

            if showGrid { drawGrid(context, size: size, center: center, scale: scale) }

            if !ghost.isEmpty {
                var path = Path()
                for (a, b) in ghost {
                    path.move(to: map(a))
                    path.addLine(to: map(b))
                }
                context.stroke(
                    path, with: .color(.gray.opacity(0.5)),
                    style: StrokeStyle(lineWidth: max(3, 2 * scale), lineCap: .round, dash: [2, 9 * scale])
                )
            }

            // Fills go under all the lines, so outlines stay crisp.
            for case .fill(let points, let rgb) in events.prefix(done) {
                var path = Path()
                path.addLines(points.map(map))
                path.closeSubpath()
                context.fill(path, with: .color(Color(rgb: rgb)), style: FillStyle(eoFill: true))
            }

            drawLines(context, done: done, map: map, scale: scale)

            for event in events.prefix(done) {
                switch event {
                case .dot(let at, let size, let rgb):
                    let d = size * scale
                    let p = map(at)
                    context.fill(
                        Path(ellipseIn: CGRect(x: p.x - d / 2, y: p.y - d / 2, width: d, height: d)),
                        with: .color(Color(rgb: rgb))
                    )
                case .write(let text, let at, let rgb):
                    context.draw(
                        Text(text).font(.system(size: 14 * scale, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(rgb: rgb)),
                        at: map(at), anchor: .bottomLeading
                    )
                default:
                    break
                }
            }

            drawStars(context, done: done, map: map, scale: scale)

            if pose.visible {
                ShellySprite.draw(
                    in: context, at: map(pose.position), heading: pose.heading,
                    size: 34 * scale, shell: shell
                )
            }
        }
    }

    private func drawGrid(_ context: GraphicsContext, size: CGSize, center: CGPoint, scale: CGFloat) {
        let step = 50 * scale
        var minor = Path()
        var x = center.x.truncatingRemainder(dividingBy: step)
        while x <= size.width {
            minor.move(to: CGPoint(x: x, y: 0))
            minor.addLine(to: CGPoint(x: x, y: size.height))
            x += step
        }
        var y = center.y.truncatingRemainder(dividingBy: step)
        while y <= size.height {
            minor.move(to: CGPoint(x: 0, y: y))
            minor.addLine(to: CGPoint(x: size.width, y: y))
            y += step
        }
        context.stroke(minor, with: .color(.black.opacity(0.06)), lineWidth: 1)
        var axes = Path()
        axes.move(to: CGPoint(x: center.x, y: 0))
        axes.addLine(to: CGPoint(x: center.x, y: size.height))
        axes.move(to: CGPoint(x: 0, y: center.y))
        axes.addLine(to: CGPoint(x: size.width, y: center.y))
        context.stroke(axes, with: .color(.black.opacity(0.12)), lineWidth: 1.5)
    }

    /// Joins neighbouring lines drawn with the same pen into one path, which draws faster and looks smoother.
    private func drawLines(_ context: GraphicsContext, done: Int, map: (Point) -> CGPoint, scale: CGFloat) {
        var path = Path()
        var currentPen: Pen?
        var last: Point?

        func flush() {
            guard let pen = currentPen, !path.isEmpty else { return }
            context.stroke(
                path, with: .color(Color(rgb: pen.color)),
                style: StrokeStyle(lineWidth: max(2.5, pen.width * scale) + 1.5, lineCap: .round, lineJoin: .round)
            )
            path = Path()
        }

        func add(_ from: Point, _ to: Point, _ pen: Pen) {
            if pen != currentPen {
                flush()
                currentPen = pen
                last = nil
            }
            if last != from { path.move(to: map(from)) }
            path.addLine(to: map(to))
            last = to
        }

        for case .move(let from, let to, let pen?) in events.prefix(done) {
            add(from, to, pen)
        }
        if done < events.count, case .move(let from, let to, let pen?) = events[done] {
            add(from, from.interpolated(to: to, progress.fraction), pen)
        }
        flush()
    }

    private func drawStars(_ context: GraphicsContext, done: Int, map: (Point) -> CGPoint, scale: CGFloat) {
        var star = context.resolve(Image(systemName: "star.fill"))
        star.shading = .color(Color(hex: 0xFFC233))
        var sparkle = context.resolve(Image(systemName: "sparkles"))
        sparkle.shading = .color(Color(hex: 0xFFC233).opacity(0.6))
        let d = 30 * scale
        for (index, point) in stars.enumerated() {
            let p = map(point)
            let rect = CGRect(x: p.x - d / 2, y: p.y - d / 2, width: d, height: d)
            if let at = starsCollectedAt[index], at < done {
                context.draw(sparkle, in: rect)
            } else {
                var shadow = context
                shadow.addFilter(.shadow(color: .orange.opacity(0.5), radius: 4 * scale))
                shadow.draw(star, in: rect)
            }
        }
    }
}

#Preview {
    let level = Curriculum.level("3.4")!
    let run = Interpreter.run(level.solution, start: level.start)
    TurtleCanvas(
        events: run.events, progress: (run.events.count, 0),
        pose: Pose(position: run.turtle.position, heading: run.turtle.heading, visible: true),
        ghost: Drawing(run.events).segments
    )
    .frame(width: 500, height: 500)
}
