import Foundation
import Testing

@testable import ShellyCodes

@MainActor
struct PlaybackTests {
    private let square = Interpreter.run("for i in range(4):\n    forward(100)\n    left(90)").events

    @Test func timelineUsesSpeedAndFitsTheTimeLimit() {
        let normal = Playback.timeline(square, speed: .normal, instant: false)
        #expect(normal.count == square.count)
        #expect(abs(normal[0] - 100 / PlaybackSpeed.normal.stepsPerSecond) < 1e-9)
        let long = Interpreter.run("for i in range(500):\n    forward(300)\n    left(91)").events
        let capped = Playback.timeline(long, speed: .normal, instant: false)
        #expect(abs((capped.last ?? 0) - PlaybackSpeed.normal.maxSeconds) < 1e-6)
        #expect(Playback.timeline(square, speed: .slow, instant: true).allSatisfy { $0 == 0 })
    }

    @Test func poseHalfwayThroughAMoveAndATurn() {
        let start = TurtleState()
        let walking = Playback.pose(events: square, start: start, progress: (0, 0.5))
        #expect(walking.position == Point(x: 50, y: 0))
        let turning = Playback.pose(events: square, start: start, progress: (1, 0.5))
        #expect(turning.heading == 45)
        let end = Playback.pose(events: square, start: start, progress: (square.count, 0))
        #expect(end.position == .zero)
    }

    @Test func instantPlayFinishesImmediately() async {
        let playback = Playback()
        await playback.play(square, from: TurtleState(), speed: .normal, instant: true)
        #expect(playback.progress.done == square.count)
        #expect(!playback.isPlaying)
        playback.reset(to: TurtleState())
        #expect(playback.events.isEmpty)
    }
}
