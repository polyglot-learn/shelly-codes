import Foundation

/// A Python idea a level can ask the child to use.
nonisolated enum Concept: String, Sendable, CaseIterable {
    case forLoop, whileLoop, ifStatement, function, functionWithParameters, variable, arithmetic

    /// Finishes the sentence "Now try it using ...".
    var phrase: String {
        switch self {
        case .forLoop: "a for loop"
        case .whileLoop: "a while loop"
        case .ifStatement: "an if"
        case .function: "a function made with def"
        case .functionWithParameters: "a function that takes a value, like def square(size):"
        case .variable: "a variable"
        case .arithmetic: "math, like + or *"
        }
    }

    func isUsed(in facts: ProgramFacts) -> Bool {
        switch self {
        case .forLoop: facts.hasFor
        case .whileLoop: facts.hasWhile
        case .ifStatement: facts.hasIf
        case .function: facts.hasDef
        case .functionWithParameters: facts.hasDefWithParameters
        case .variable: facts.hasAssignment
        case .arithmetic: facts.hasArithmetic
        }
    }
}

nonisolated struct Level: Identifiable, Sendable {
    /// "chapter.number", e.g. "3.2". Stored with progress, so never change one once shipped.
    let id: String
    let title: String
    /// What Shelly says. Supports `code` in backticks and **bold**.
    let story: String
    let starter: String
    let solution: String
    let chips: [String]
    let hints: [String]
    var stars: [Point] = []
    var checksDrawing = false
    var checksOutput = false
    var concepts: [Concept] = []
    /// Commands the program must call, e.g. "color". Aliases like pencolor count.
    var calls: [String] = []
    /// Lines of code for the "short code" star. nil means any length earns it.
    var par: Int?
    var start = TurtleState()

    var chapterNumber: Int { Int(id.split(separator: ".")[0]) ?? 0 }
    var number: Int { Int(id.split(separator: ".")[1]) ?? 0 }

    /// The run of the solution: its drawing is the dotted target and its output the expected output.
    var target: RunResult {
        Interpreter.run(solution, start: start, seed: 0)
    }
}

nonisolated struct Chapter: Identifiable, Sendable {
    let id: Int
    let title: String
    let subtitle: String
    let symbol: String
    let colorHex: UInt32
    let levels: [Level]
}
