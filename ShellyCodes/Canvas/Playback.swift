import Foundation
import Observation

/// Where Shelly is at one moment of a replay.
struct Pose: Equatable {
    var position: Point
    var heading: Double
    var visible: Bool
}

/// Replays a run's events over time, so children watch Shelly walk instead of seeing the answer appear.
@Observable
final class Playback {
    private(set) var events: [TurtleEvent] = []
    private(set) var start = TurtleState()
    private(set) var elapsed: Double = 0
    private(set) var isPlaying = false
    private var ends: [Double] = []
    private var skipRequested = false

    var total: Double { ends.last ?? 0 }

    /// How many events are finished, and how far through the next one (0...1).
    var progress: (done: Int, fraction: Double) {
        guard !ends.isEmpty else { return (events.count, 0) }
        if elapsed >= total { return (events.count, 0) }
        var low = 0
        var high = ends.count - 1
        while low < high {
            let mid = (low + high) / 2
            if ends[mid] > elapsed { high = mid } else { low = mid + 1 }
        }
        let begin = low == 0 ? 0 : ends[low - 1]
        let duration = ends[low] - begin
        return (low, duration > 0 ? (elapsed - begin) / duration : 1)
    }

    var pose: Pose {
        Self.pose(events: events, start: start, progress: progress)
    }

    func reset(to start: TurtleState) {
        skipRequested = true
        events = []
        ends = []
        elapsed = 0
        isPlaying = false
        self.start = start
    }

    /// Replays the events and returns when the replay finishes or is skipped.
    func play(_ events: [TurtleEvent], from start: TurtleState, speed: PlaybackSpeed, instant: Bool = false) async {
        self.start = start
        self.events = events
        ends = Self.timeline(events, speed: speed, instant: instant)
        elapsed = 0
        skipRequested = false
        guard total > 0 else { return }

        isPlaying = true
        let began = ContinuousClock.now
        while !skipRequested, !Task.isCancelled, elapsed < total {
            try? await Task.sleep(for: .milliseconds(16))
            let seconds = (ContinuousClock.now - began) / .seconds(1)
            elapsed = min(total, seconds)
        }
        if skipRequested || Task.isCancelled { elapsed = total }
        isPlaying = false
    }

    func skipToEnd() {
        skipRequested = true
        elapsed = total
    }

    /// The time at which each event finishes.
    static func timeline(_ events: [TurtleEvent], speed: PlaybackSpeed, instant: Bool) -> [Double] {
        var durations = events.map { event -> Double in
            if instant { return 0 }
            switch event {
            case .move(let from, let to, _): return from.distance(to: to) / speed.stepsPerSecond
            case .turn(let from, let to): return abs(to - from) / speed.degreesPerSecond
            case .print: return 0.25
            case .dot, .write, .fill: return 0.2
            case .background: return 0.15
            case .visibility: return 0
            }
        }
        let total = durations.reduce(0, +)
        if total > speed.maxSeconds {
            let scale = speed.maxSeconds / total
            durations = durations.map { $0 * scale }
        }
        var running = 0.0
        return durations.map {
            running += $0
            return running
        }
    }

    static func pose(events: [TurtleEvent], start: TurtleState, progress: (done: Int, fraction: Double)) -> Pose {
        var pose = Pose(position: start.position, heading: start.heading, visible: start.visible)
        for event in events.prefix(progress.done) {
            apply(event, to: &pose, fraction: 1)
        }
        if progress.done < events.count {
            apply(events[progress.done], to: &pose, fraction: progress.fraction)
        }
        return pose
    }

    private static func apply(_ event: TurtleEvent, to pose: inout Pose, fraction: Double) {
        switch event {
        case .move(let from, let to, _):
            pose.position = from.interpolated(to: to, fraction)
        case .turn(let from, let to):
            pose.heading = from + (to - from) * fraction
        case .visibility(let visible):
            if fraction >= 1 { pose.visible = visible }
        default:
            break
        }
    }
}
