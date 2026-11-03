import Foundation
import Testing

@testable import ShellyCodes

struct TurtleTests {
    @Test func squareReturnsHome() {
        let result = Interpreter.run("for i in range(4):\n    forward(100)\n    left(90)")
        #expect(result.error == nil)
        #expect(result.turtle.position == .zero)
        #expect(Drawing(result.events).segments.count == 4)
        if case .move(_, let to, _) = result.events[0] { #expect(to == Point(x: 100, y: 0)) }
        if case .move(_, let to, _) = result.events[2] { #expect(to == Point(x: 100, y: 100)) }
    }

    @Test func circleMatchesPythonAndComesBack() {
        let result = Interpreter.run("circle(50)")
        #expect(result.error == nil)
        // Python's turtle draws circle(50) with 1 + int(min(11 + 50/6, 59)) = 20 steps.
        #expect(Drawing(result.events).segments.count == 20)
        #expect(result.turtle.position.distance(to: .zero) < 1e-6)
        let top = Drawing(result.events).segments.map(\.1.y).max() ?? 0
        #expect(abs(top - 100) < 1)
    }

    @Test func penUpMovesWithoutDrawing() {
        let result = Interpreter.run("penup()\nforward(50)\npendown()\nforward(50)")
        #expect(Drawing(result.events).segments.count == 1)
        #expect(Drawing(result.events).path.count == 2)
    }

    @Test func positionAndHeadingQuestions() {
        let result = Interpreter.run("goto(30, 40)\nsetheading(-90)\nright(90)\nprint(xcor(), ycor(), heading())\nhome()\nprint(xcor(), heading())")
        #expect(result.output == "30.0 40.0 180.0\n0.0 0.0\n")
    }

    @Test func colorsPensFillsDotsAndText() {
        let result = Interpreter.run(
            """
            color("red", "#00ff00")
            pensize(5)
            begin_fill()
            for i in range(3):
                forward(50)
                left(120)
            end_fill()
            dot(20, "blue")
            write("Hi!")
            bgcolor(0, 0, 255)
            hideturtle()
            """
        )
        #expect(result.error == nil)
        #expect(result.events.contains { if case .move(_, _, Pen(color: RGB(hex: 0xFF0000), width: 5)?) = $0 { true } else { false } })
        #expect(result.events.contains { if case .fill(let points, RGB(hex: 0x00FF00)) = $0 { points.count == 4 } else { false } })
        #expect(result.events.contains(.dot(at: .zero, size: 20, color: RGB(hex: 0x0000FF))))
        #expect(result.events.contains(.write("Hi!", at: .zero, color: RGB(hex: 0xFF0000))))
        #expect(result.events.contains(.background(RGB(hex: 0x0000FF))))
        #expect(result.turtle.visible == false)
    }

    @Test func colorParsing() {
        #expect(RGB.parse("Sky Blue") == RGB(hex: 0x87CEEB))
        #expect(RGB.parse("#f80") == RGB(hex: 0xFF8800))
        #expect(RGB.parse("#FF8800") == RGB(hex: 0xFF8800))
        #expect(RGB.parse("blurple") == nil)
    }

    @Test func coverageCheck() {
        let square: [(Point, Point)] = [
            (Point(x: 0, y: 0), Point(x: 100, y: 0)), (Point(x: 100, y: 0), Point(x: 100, y: 100)),
        ]
        let nearly = [(Point(x: 0, y: 3), Point(x: 100, y: 3)), (Point(x: 103, y: 0), Point(x: 103, y: 100))]
        #expect(Drawing.covers(nearly, square))
        #expect(!Drawing.covers([square[0]], square))
    }
}
