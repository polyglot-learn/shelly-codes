import Foundation

nonisolated enum Verdict: Equatable, Sendable {
    case error(PyError)
    case notYet(String)
    case solved
}

/// Decides whether a run solves a level, and if not, what to tell the child.
nonisolated enum LevelChecker {
    /// How close Shelly has to pass to a star to pick it up.
    static let starRadius = 16.0

    static let aliases: [String: Set<String>] = [
        "color": ["color", "pencolor"],
        "penup": ["penup", "pu", "up"],
        "pendown": ["pendown", "pd", "down"],
        "forward": ["forward", "fd"],
        "pensize": ["pensize", "width"],
    ]

    static func check(_ level: Level, _ result: RunResult, target: RunResult? = nil) -> Verdict {
        if let error = result.error { return .error(error) }

        let missing = level.stars.count - collectedStars(level.stars, in: result.events).count
        if missing > 0 {
            return .notYet(
                missing == 1
                    ? "So close! Shelly still needs to reach 1 more star."
                    : "Almost! Shelly still needs to reach \(missing) more stars."
            )
        }

        let target = target ?? level.target
        if level.checksDrawing {
            let drawn = Drawing(result.events).segments
            let goal = Drawing(target.events).segments
            if !Drawing.covers(drawn, goal) {
                return .notYet("The picture isn't finished yet. Shelly needs to trace all the dotted lines.")
            }
            if !Drawing.covers(goal, drawn) {
                return .notYet("Shelly drew some lines that aren't in the picture. Make the drawing match the dotted lines.")
            }
        }

        if level.checksOutput {
            let got = result.outputLines.map(normalized).filter { !$0.isEmpty }
            let expected = target.outputLines.map(normalized).filter { !$0.isEmpty }
            if got != expected {
                let goal = target.outputLines.joined(separator: "\n")
                if got.isEmpty {
                    return .notYet("Shelly didn't say anything. Use print( ) so Shelly says:\n\(goal)")
                }
                return .notYet("Shelly should say:\n\(goal)")
            }
        }

        let facts = ProgramFacts(result.program)
        if let concept = level.concepts.first(where: { !$0.isUsed(in: facts) }) {
            return .notYet("It works! Now try it using \(concept.phrase).")
        }
        if let command = level.calls.first(where: { facts.calledNames.isDisjoint(with: aliases[$0] ?? [$0]) }) {
            return .notYet("It works! Now try it using \(command)( ).")
        }
        return .solved
    }

    /// Ignores capitals, punctuation and extra spaces, so "hello shelly" matches "Hello, Shelly!".
    static func normalized(_ line: String) -> String {
        let kept = line.lowercased().unicodeScalars.map {
            CharacterSet.alphanumerics.contains($0) || $0 == "-" ? Character($0) : " "
        }
        return String(kept).split(separator: " ").joined(separator: " ")
    }

    /// For each star picked up, the index of the move event that reaches it.
    static func collectedStars(_ stars: [Point], in events: [TurtleEvent]) -> [Int: Int] {
        var collected: [Int: Int] = [:]
        for (eventIndex, event) in events.enumerated() {
            guard case .move(let from, let to, _) = event else { continue }
            for (starIndex, star) in stars.enumerated() where collected[starIndex] == nil {
                if star.distance(toSegment: from, to) <= starRadius {
                    collected[starIndex] = eventIndex
                }
            }
        }
        return collected
    }

    /// 1 star for solving, 1 for short code (at most `par` lines), 1 for no hints.
    static func rating(_ level: Level, code: String, hintsUsed: Int) -> Int {
        var stars = 1
        if let par = level.par {
            if codeLineCount(code) <= par { stars += 1 }
        } else {
            stars += 1
        }
        if hintsUsed == 0 { stars += 1 }
        return stars
    }
}
