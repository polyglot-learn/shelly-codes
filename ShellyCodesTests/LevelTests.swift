import Foundation
import Testing

@testable import ShellyCodes

struct LevelTests {
    @Test(arguments: Curriculum.levels.map(\.id))
    func solutionSolvesAndStarterDoesNot(id: String) throws {
        let level = try #require(Curriculum.level(id))
        let solution = Interpreter.run(level.solution, start: level.start, seed: 0)
        #expect(LevelChecker.check(level, solution) == .solved)
        let starter = LevelChecker.check(level, Interpreter.run(level.starter, start: level.start, seed: 0))
        if id == "1.1" {
            #expect(starter == .solved, "the first level is solved by tapping Run")
        } else {
            #expect(starter != .solved, "the starter code must leave something to do")
        }
    }

    @Test(arguments: Curriculum.levels.map(\.id))
    func levelIsWellFormed(id: String) throws {
        let level = try #require(Curriculum.level(id))
        #expect(!level.hints.isEmpty)
        #expect(!level.chips.isEmpty)
        #expect(level.checksDrawing || level.checksOutput || !level.stars.isEmpty, "a level needs a goal")
        if let par = level.par {
            #expect(codeLineCount(level.solution) <= par, "the solution must earn the short-code star")
        }
        // Everything must fit on the canvas, which shows at least -200...200.
        var points = level.stars
        for case .move(let from, let to, _) in level.target.events { points += [from, to] }
        #expect(points.allSatisfy { abs($0.x) <= 200 && abs($0.y) <= 200 })
    }

    @Test func idsAreUniqueAndMatchTheirChapters() {
        let ids = Curriculum.levels.map(\.id)
        #expect(Set(ids).count == ids.count)
        for chapter in Curriculum.chapters {
            for (offset, level) in chapter.levels.enumerated() {
                #expect(level.chapterNumber == chapter.id)
                #expect(level.number == offset + 1)
            }
        }
        #expect(Curriculum.maxStars == 81)
    }

    @Test func feedbackExplainsWhatIsMissing() throws {
        let stars = try #require(Curriculum.level("1.3"))
        let short = LevelChecker.check(stars, Interpreter.run("forward(150)", start: stars.start))
        #expect(short == .notYet("So close! Shelly still needs to reach 1 more star."))

        let square = try #require(Curriculum.level("1.5"))
        let extra = Interpreter.run(
            "for i in range(4):\n    forward(100)\n    left(90)\nright(90)\nforward(50)", start: square.start)
        guard case .notYet(let message) = LevelChecker.check(square, extra) else {
            Issue.record("extra lines should not pass")
            return
        }
        #expect(message.contains("aren't in the picture"))

        let loop = try #require(Curriculum.level("3.1"))
        let noLoop = Interpreter.run(square.solution, start: loop.start)
        #expect(LevelChecker.check(loop, noLoop) == .notYet("It works! Now try it using a for loop."))

        let hello = try #require(Curriculum.level("2.1"))
        #expect(LevelChecker.check(hello, Interpreter.run("print('hello   SHELLY')")) == .solved)
        guard case .notYet(let silent) = LevelChecker.check(hello, Interpreter.run("forward(1)")) else {
            Issue.record("no output should not pass")
            return
        }
        #expect(silent.contains("didn't say anything"))

        let math = try #require(Curriculum.level("2.2"))
        #expect(LevelChecker.check(math, Interpreter.run("print(84)")) == .notYet("It works! Now try it using math, like + or *."))

        let red = try #require(Curriculum.level("4.1"))
        let pencolor = "pencolor('red')\nfor i in range(4):\n    forward(100)\n    left(90)"
        #expect(LevelChecker.check(red, Interpreter.run(pencolor, start: red.start)) == .solved)
    }

    @Test func rating() throws {
        let level = try #require(Curriculum.level("3.1"))
        #expect(LevelChecker.rating(level, code: level.solution, hintsUsed: 0) == 3)
        #expect(LevelChecker.rating(level, code: level.solution, hintsUsed: 1) == 2)
        let long = "forward(100)\nleft(90)\n" + level.solution
        #expect(LevelChecker.rating(level, code: long, hintsUsed: 2) == 1)
        #expect(codeLineCount("# comment\n\nforward(1)\n   \n") == 1)
    }

    @Test func outputNormalization() {
        #expect(LevelChecker.normalized("  Hello,   Shelly! ") == "hello shelly")
        #expect(LevelChecker.normalized("-3 is odd") == "-3 is odd")
    }

    @Test func starsAreCollectedInOrder() {
        let stars = [Point(x: 100, y: 0), Point(x: 0, y: 500)]
        let events = Interpreter.run("forward(50)\nforward(50)").events
        #expect(LevelChecker.collectedStars(stars, in: events) == [0: 1])
    }

    @Test(arguments: Idea.all.map(\.title))
    func ideasRunWithoutErrors(title: String) throws {
        let idea = try #require(Idea.all.first { $0.title == title })
        #expect(Interpreter.run(idea.code).error == nil)
    }

    @Test func blankCreationRuns() {
        #expect(Interpreter.run(Creation.blankCode).error == nil)
    }
}
