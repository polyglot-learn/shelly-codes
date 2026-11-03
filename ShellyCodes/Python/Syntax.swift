import Foundation

nonisolated indirect enum Expr: Sendable {
    case int(Int)
    case float(Double)
    case string(String)
    case bool(Bool)
    case none
    case name(String)
    case list([Expr])
    case unary(String, Expr)
    case binary(String, Expr, Expr)
    case compare(Expr, [Comparison])
    case and(Expr, Expr)
    case or(Expr, Expr)
    case call(Expr, [Expr], [KeywordArgument])
    case attribute(Expr, String)
    case index(Expr, Expr)
}

nonisolated struct Comparison: Sendable {
    var op: String
    var right: Expr
}

nonisolated struct KeywordArgument: Sendable {
    var name: String
    var value: Expr
}

nonisolated struct Branch: Sendable {
    var condition: Expr
    var body: [Stmt]
}

nonisolated struct Stmt: Sendable {
    var kind: Kind
    var line: Int

    indirect enum Kind: Sendable {
        case expr(Expr)
        case assign(Expr, Expr)
        case augAssign(Expr, String, Expr)
        case ifs([Branch], [Stmt]?)
        case whileLoop(Expr, [Stmt])
        case forLoop(String, Expr, [Stmt])
        case def(String, [String], [Stmt])
        case ret(Expr?)
        case brk
        case cont
        case pass
        case importModule(String, alias: String)
        case fromImport(String, names: [String]?)
        case global([String])
    }
}

/// What a program uses, so a level can ask for "a for loop" or "a function".
nonisolated struct ProgramFacts: Equatable, Sendable {
    var hasFor = false
    var hasWhile = false
    var hasIf = false
    var hasDef = false
    var hasDefWithParameters = false
    var hasAssignment = false
    var hasArithmetic = false
    var calledNames: Set<String> = []

    init(_ program: [Stmt]) {
        visit(program)
    }

    private mutating func visit(_ stmts: [Stmt]) {
        for stmt in stmts {
            switch stmt.kind {
            case .expr(let e):
                visit(e)
            case .assign(let target, let value):
                hasAssignment = true
                visit(target)
                visit(value)
            case .augAssign(let target, _, let value):
                hasAssignment = true
                hasArithmetic = true
                visit(target)
                visit(value)
            case .ifs(let branches, let orelse):
                hasIf = true
                for branch in branches {
                    visit(branch.condition)
                    visit(branch.body)
                }
                visit(orelse ?? [])
            case .whileLoop(let condition, let body):
                hasWhile = true
                visit(condition)
                visit(body)
            case .forLoop(_, let iterable, let body):
                hasFor = true
                visit(iterable)
                visit(body)
            case .def(_, let params, let body):
                hasDef = true
                if !params.isEmpty { hasDefWithParameters = true }
                visit(body)
            case .ret(let value):
                if let value { visit(value) }
            case .brk, .cont, .pass, .importModule, .fromImport, .global:
                break
            }
        }
    }

    private mutating func visit(_ expr: Expr) {
        switch expr {
        case .int, .float, .string, .bool, .none, .name:
            break
        case .list(let items):
            items.forEach { visit($0) }
        case .unary(_, let e):
            visit(e)
        case .binary(_, let a, let b):
            hasArithmetic = true
            visit(a)
            visit(b)
        case .compare(let first, let rest):
            visit(first)
            rest.forEach { visit($0.right) }
        case .and(let a, let b), .or(let a, let b):
            visit(a)
            visit(b)
        case .call(let callee, let args, let kwargs):
            switch callee {
            case .name(let name): calledNames.insert(name)
            case .attribute(_, let name): calledNames.insert(name)
            default: break
            }
            visit(callee)
            args.forEach { visit($0) }
            kwargs.forEach { visit($0.value) }
        case .attribute(let e, _):
            visit(e)
        case .index(let a, let b):
            visit(a)
            visit(b)
        }
    }
}

/// Counts the lines that do something: not blank, not only a comment.
nonisolated func codeLineCount(_ source: String) -> Int {
    Lexer.normalize(source).split(separator: "\n").filter {
        let trimmed = $0.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && !trimmed.hasPrefix("#")
    }.count
}
