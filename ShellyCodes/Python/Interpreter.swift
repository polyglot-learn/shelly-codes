import Foundation

nonisolated struct RunResult: Sendable {
    var program: [Stmt]
    var events: [TurtleEvent]
    var output: String
    var error: PyError?
    var turtle: TurtleState

    var outputLines: [String] {
        var lines = output.components(separatedBy: "\n")
        if lines.last == "" { lines.removeLast() }
        return lines
    }
}

/// Runs a program and records what Shelly did. The run finishes before anything is shown,
/// so the canvas can replay it at any speed, and limits stop loops that never end.
nonisolated final class Interpreter {
    static let maxSteps = 50_000
    static let maxEvents = 12_000
    static let maxDepth = 60
    static let maxOutput = 20_000

    private struct Frame {
        let function: PyFunction
        var locals: [String: Value] = [:]
        var globalNames: Set<String> = []
    }

    private enum Flow: Error {
        case brk, cont, ret
    }

    private var globals: [String: Value] = [:]
    private var frames: [Frame] = []
    private var turtle: TurtleState
    private var events: [TurtleEvent] = []
    private var output = ""
    private var steps = 0
    private var line = 1
    private var returnValue = Value.none
    private var fillPath: [Point]?
    private var rng: SplitMix

    static func run(
        _ source: String,
        start: TurtleState = TurtleState(),
        seed: UInt64 = UInt64.random(in: 0...UInt64.max)
    ) -> RunResult {
        Interpreter(start: start, seed: seed).run(source)
    }

    private init(start: TurtleState, seed: UInt64) {
        turtle = start
        rng = SplitMix(seed: seed)
    }

    private func run(_ source: String) -> RunResult {
        var program: [Stmt] = []
        var failure: PyError?
        do {
            program = try Parser.parse(source)
            try exec(program)
        } catch let error as PyError {
            failure = error
        } catch Flow.brk {
            failure = PyError(line: line, message: "break only works inside a for or while loop.")
        } catch Flow.cont {
            failure = PyError(line: line, message: "continue only works inside a for or while loop.")
        } catch Flow.ret {
            failure = PyError(line: line, message: "return only works inside a function made with def.")
        } catch {
            failure = PyError(line: line, message: "Something went wrong. Try changing this line.")
        }
        return RunResult(program: program, events: events, output: output, error: failure, turtle: turtle)
    }

    private func fail(_ message: String) -> PyError {
        PyError(line: line, message: message)
    }

    private func tick() throws {
        steps += 1
        if steps > Self.maxSteps {
            throw fail(
                "Shelly got dizzy! Your code took more than \(Self.maxSteps.formatted()) steps. Is there a loop that never stops?"
            )
        }
    }

    // MARK: - Statements

    private func exec(_ stmts: [Stmt]) throws {
        for stmt in stmts { try exec(stmt) }
    }

    private func exec(_ stmt: Stmt) throws {
        line = stmt.line
        try tick()
        switch stmt.kind {
        case .expr(let expr):
            _ = try eval(expr)
        case .assign(let target, let value):
            try assign(target, try eval(value))
        case .augAssign(let target, let op, let value):
            let current = try eval(target)
            let right = try eval(value)
            line = stmt.line
            try assign(target, try binary(op, current, right))
        case .ifs(let branches, let orelse):
            for branch in branches where try eval(branch.condition).truthy {
                try exec(branch.body)
                return
            }
            if let orelse { try exec(orelse) }
        case .whileLoop(let condition, let body):
            while try eval(condition).truthy {
                do {
                    try exec(body)
                } catch Flow.brk {
                    break
                } catch Flow.cont {}
                line = stmt.line
                try tick()
            }
        case .forLoop(let name, let iterable, let body):
            try forLoop(name, try eval(iterable), body, line: stmt.line)
        case .def(let name, let params, let body):
            try assign(.name(name), .function(PyFunction(name: name, params: params, body: body)))
        case .ret(let value):
            guard !frames.isEmpty else {
                throw fail("return only works inside a function made with def.")
            }
            returnValue = try value.map(eval) ?? .none
            throw Flow.ret
        case .brk:
            throw Flow.brk
        case .cont:
            throw Flow.cont
        case .pass:
            break
        case .importModule(let module, let alias):
            try checkModule(module)
            try assign(.name(alias), .module(module))
        case .fromImport(let module, let names):
            try checkModule(module)
            for name in names ?? [] {
                guard let member = Self.member(module, name) else {
                    throw fail("The \(module) module doesn't have \(name).")
                }
                try assign(.name(name), member)
            }
        case .global(let names):
            if !frames.isEmpty {
                frames[frames.count - 1].globalNames.formUnion(names)
            }
        }
    }

    private func forLoop(_ name: String, _ iterable: Value, _ body: [Stmt], line loopLine: Int) throws {
        func iteration(_ value: Value) throws -> Bool {
            line = loopLine
            try tick()
            try assign(.name(name), value)
            do {
                try exec(body)
            } catch Flow.brk {
                return false
            } catch Flow.cont {}
            return true
        }
        switch iterable {
        case .range(let start, let stop, let step):
            var i = start
            while step > 0 ? i < stop : i > stop {
                guard try iteration(.int(i)) else { return }
                i += step
            }
        case .list(let list):
            for item in list.items {
                guard try iteration(item) else { return }
            }
        case .str(let text):
            for char in text {
                guard try iteration(.str(String(char))) else { return }
            }
        case .int(let n):
            throw fail("You can't loop over a number by itself. Use range, like: for i in range(\(n)):")
        default:
            throw fail("A for loop needs a range(...), a list or a word to go through, not \(iterable.kind).")
        }
    }

    private func checkModule(_ module: String) throws {
        guard Self.modules[module] != nil else {
            throw fail("Shelly only knows the turtle, random, math and time modules, not \(module).")
        }
    }

    private func assign(_ target: Expr, _ value: Value) throws {
        switch target {
        case .name(let name):
            if let frame = frames.last, !frame.globalNames.contains(name) {
                frames[frames.count - 1].locals[name] = value
            } else {
                globals[name] = value
            }
        case .index(let container, let indexExpr):
            let list = try eval(container)
            let index = try eval(indexExpr)
            guard case .list(let items) = list else {
                throw fail("You can only change items in a list, not in \(list.kind).")
            }
            let position = try listPosition(index, count: items.items.count)
            items.items[position] = value
        default:
            throw fail("You can only put a value into a variable name, like size = 50.")
        }
    }

    // MARK: - Expressions

    private func eval(_ expr: Expr) throws -> Value {
        switch expr {
        case .int(let i): return .int(i)
        case .float(let d): return .float(d)
        case .string(let s): return .str(s)
        case .bool(let b): return .bool(b)
        case .none: return .none
        case .name(let name): return try lookup(name)
        case .list(let items): return .list(PyList(try items.map(eval)))
        case .unary(let op, let operand):
            return try unary(op, try eval(operand))
        case .binary(let op, let a, let b):
            let left = try eval(a)
            let right = try eval(b)
            return try binary(op, left, right)
        case .compare(let first, let rest):
            var left = try eval(first)
            for comparison in rest {
                let right = try eval(comparison.right)
                guard try compare(comparison.op, left, right) else { return .bool(false) }
                left = right
            }
            return .bool(true)
        case .and(let a, let b):
            let left = try eval(a)
            return left.truthy ? try eval(b) : left
        case .or(let a, let b):
            let left = try eval(a)
            return left.truthy ? left : try eval(b)
        case .call(let calleeExpr, let argExprs, let kwargExprs):
            let callee = try eval(calleeExpr)
            let args = try argExprs.map(eval)
            var kwargs: [String: Value] = [:]
            for kwarg in kwargExprs { kwargs[kwarg.name] = try eval(kwarg.value) }
            var calledName: String?
            if case .name(let name) = calleeExpr { calledName = name }
            return try call(callee, args, kwargs, name: calledName)
        case .attribute(let objectExpr, let name):
            return try attribute(try eval(objectExpr), name)
        case .index(let containerExpr, let indexExpr):
            let container = try eval(containerExpr)
            let index = try eval(indexExpr)
            switch container {
            case .list(let list):
                return list.items[try listPosition(index, count: list.items.count)]
            case .str(let text):
                let chars = Array(text)
                return .str(String(chars[try listPosition(index, count: chars.count)]))
            default:
                throw fail("You can only use [ ] on a list or a word, not on \(container.kind).")
            }
        }
    }

    private func listPosition(_ index: Value, count: Int) throws -> Int {
        guard let i = index.integer else {
            throw fail("Positions in a list are whole numbers, like items[0].")
        }
        let position = i < 0 ? count + i : i
        guard position >= 0, position < count else {
            if count == 0 { throw fail("That list is empty, so there's nothing at position \(i).") }
            throw fail(
                "There's nothing at position \(i). This has \(count) item\(count == 1 ? "" : "s"), and positions start at 0, so the last one is \(count - 1)."
            )
        }
        return position
    }

    private func lookup(_ name: String) throws -> Value {
        if let frame = frames.last {
            if let value = frame.locals[name] { return value }
            if frame.function.localNames.contains(name), !frame.globalNames.contains(name) {
                if globals[name] != nil {
                    throw fail(
                        "Inside \(frame.function.name), \(name) is changed, so Python treats it as a new variable that has no value yet. To change the \(name) from outside, add global \(name) as the first line of the function."
                    )
                }
                throw fail("\(name) doesn't have a value yet. Give it one first, like \(name) = 0.")
            }
        }
        if let value = globals[name] { return value }
        if Self.globalBuiltins.contains(name) { return .builtin(name) }
        if Self.modules[name] != nil { return .module(name) }
        if name == "pi" { return .float(.pi) }
        throw unknownName(name)
    }

    private func unknownName(_ name: String) -> PyError {
        var known = Set(globals.keys).union(Self.globalBuiltins)
        if let frame = frames.last { known.formUnion(frame.locals.keys) }
        if let match = known.first(where: { $0.lowercased() == name.lowercased() }) {
            return fail("Python cares about capital letters. Did you mean \(match)?")
        }
        if let match = Suggest.closest(to: name, in: known.union(["True", "False", "None"])) {
            return fail("Shelly doesn't know what \(name) means. Did you mean \(match)?")
        }
        return fail(
            "Shelly doesn't know what \(name) means. If it's a word to show, put quotes around it: \"\(name)\". If it's a variable, give it a value first, like \(name) = 5."
        )
    }

    private func attribute(_ object: Value, _ name: String) throws -> Value {
        switch object {
        case .module(let module):
            guard let member = Self.member(module, name) else {
                if let match = Suggest.closest(to: name, in: Self.modules[module] ?? []) {
                    throw fail("The \(module) module doesn't have \(name). Did you mean \(match)?")
                }
                throw fail("The \(module) module doesn't have \(name).")
            }
            return member
        case .list where ["append", "pop", "insert", "remove", "reverse", "index", "count"].contains(name):
            return .method(object, name)
        case .str where ["upper", "lower", "title", "capitalize", "strip", "replace", "count"].contains(name):
            return .method(object, name)
        default:
            throw fail("\(object.kind.prefix(1).uppercased() + object.kind.dropFirst()) doesn't have .\(name).")
        }
    }

    // MARK: - Operators

    private func unary(_ op: String, _ value: Value) throws -> Value {
        switch op {
        case "not":
            return .bool(!value.truthy)
        default:
            switch value {
            case .int(let i):
                return .int(op == "-" ? -i : i)
            case .bool(let b):
                return .int(op == "-" ? (b ? -1 : 0) : (b ? 1 : 0))
            case .float(let d):
                return .float(op == "-" ? -d : d)
            default:
                throw fail("You can't put \(op) in front of \(value.kind).")
            }
        }
    }

    private func binary(_ op: String, _ a: Value, _ b: Value) throws -> Value {
        // Text and lists first.
        switch (op, a, b) {
        case ("+", .str(let x), .str(let y)):
            return .str(try limited(x + y))
        case ("+", .list(let x), .list(let y)):
            return .list(PyList(x.items + y.items))
        case ("*", .str(let s), _) where b.integer != nil, ("*", _, .str(let s)) where a.integer != nil:
            let n = max(0, (b.integer ?? a.integer)!)
            guard s.count * n <= Self.maxOutput else { throw fail("That word would be too long!") }
            return .str(String(repeating: s, count: n))
        case ("*", .list(let l), _) where b.integer != nil, ("*", _, .list(let l)) where a.integer != nil:
            let n = max(0, (b.integer ?? a.integer)!)
            guard l.items.count * n <= Self.maxOutput else { throw fail("That list would be too long!") }
            return .list(PyList(Array(repeating: l.items, count: n).flatMap { $0 }))
        case ("+", .str, _) where b.number != nil, ("+", _, .str) where a.number != nil:
            throw fail(
                "You can't add a word and a number. Turn the number into a word first with str(...), like \"Score: \" + str(5)."
            )
        default:
            break
        }

        guard let x = a.number, let y = b.number else {
            let symbol = op == "*" ? "*" : op
            throw fail("You can't use \(symbol) with \(a.kind) and \(b.kind).")
        }

        if let i = a.integer, let j = b.integer {
            switch op {
            case "+": return try checked(i.addingReportingOverflow(j))
            case "-": return try checked(i.subtractingReportingOverflow(j))
            case "*": return try checked(i.multipliedReportingOverflow(by: j))
            case "//", "%":
                guard j != 0 else { throw divideByZero() }
                var q = i / j
                if i % j != 0, (i < 0) != (j < 0) { q -= 1 }
                return .int(op == "//" ? q : i - q * j)
            case "**" where j >= 0:
                var result = 1
                for _ in 0..<j {
                    let (product, overflow) = result.multipliedReportingOverflow(by: i)
                    if overflow { throw tooBig() }
                    result = product
                    if result == 0 || result == 1 { break }
                }
                return .int(j == 0 ? 1 : result)
            default:
                break
            }
        }

        let result: Double
        switch op {
        case "+": result = x + y
        case "-": result = x - y
        case "*": result = x * y
        case "/":
            guard y != 0 else { throw divideByZero() }
            result = x / y
        case "//":
            guard y != 0 else { throw divideByZero() }
            result = (x / y).rounded(.down)
        case "%":
            guard y != 0 else { throw divideByZero() }
            result = x - y * (x / y).rounded(.down)
        case "**":
            if x == 0 && y < 0 { throw divideByZero() }
            result = pow(x, y)
        default:
            throw fail("Shelly doesn't know the \(op) operator.")
        }
        guard result.isFinite else { throw tooBig() }
        return .float(result)
    }

    private func checked(_ result: (partialValue: Int, overflow: Bool)) throws -> Value {
        if result.overflow { throw tooBig() }
        return .int(result.partialValue)
    }

    private func tooBig() -> PyError {
        fail("That number is too big for Shelly!")
    }

    private func divideByZero() -> PyError {
        fail("Oops! You can't divide by zero. Even Python can't do that.")
    }

    private func limited(_ text: String) throws -> String {
        guard text.count <= Self.maxOutput else { throw fail("That word would be too long!") }
        return text
    }

    private func compare(_ op: String, _ a: Value, _ b: Value) throws -> Bool {
        switch op {
        case "==": return a.equals(b)
        case "!=": return !a.equals(b)
        case "in", "not in":
            let found: Bool
            switch b {
            case .list(let list): found = list.items.contains { $0.equals(a) }
            case .str(let text):
                guard case .str(let part) = a else {
                    throw fail("To check if something is in a word, it has to be a word too.")
                }
                found = text.contains(part)
            case .range(let start, let stop, let step):
                guard let i = a.integer else { found = false; break }
                let inside = step > 0 ? (i >= start && i < stop) : (i <= start && i > stop)
                found = inside && (i - start) % step == 0
            default:
                throw fail("You can only check if something is in a list, a word or a range.")
            }
            return op == "in" ? found : !found
        default:
            let order: ComparisonResult
            if let x = a.number, let y = b.number {
                order = x < y ? .orderedAscending : (x > y ? .orderedDescending : .orderedSame)
            } else if case .str(let x) = a, case .str(let y) = b {
                order = x < y ? .orderedAscending : (x > y ? .orderedDescending : .orderedSame)
            } else {
                throw fail("You can't compare \(a.kind) with \(b.kind) using \(op).")
            }
            switch op {
            case "<": return order == .orderedAscending
            case ">": return order == .orderedDescending
            case "<=": return order != .orderedDescending
            default: return order != .orderedAscending
            }
        }
    }

    // MARK: - Calls

    private func call(_ callee: Value, _ args: [Value], _ kwargs: [String: Value], name: String?) throws -> Value {
        switch callee {
        case .function(let function):
            return try callFunction(function, args, kwargs)
        case .builtin(let builtin):
            return try callBuiltin(builtin, args, kwargs, typed: name ?? builtin)
        case .method(let receiver, let method):
            return try callMethod(receiver, method, args)
        default:
            if let name {
                throw fail(
                    "\(name) holds \(callee.kind), so it can't be used as a command with ( ). Did you use \(name) as a variable name by mistake?"
                )
            }
            throw fail("\(callee.kind.prefix(1).uppercased() + callee.kind.dropFirst()) can't be used as a command with ( ).")
        }
    }

    private func callFunction(_ function: PyFunction, _ args: [Value], _ kwargs: [String: Value]) throws -> Value {
        var locals: [String: Value] = [:]
        guard args.count <= function.params.count else {
            throw fail(arityMessage(function, given: args.count + kwargs.count))
        }
        for (param, value) in zip(function.params, args) { locals[param] = value }
        for (key, value) in kwargs {
            guard function.params.contains(key), locals[key] == nil else {
                throw fail("\(function.name) doesn't have a value called \(key).")
            }
            locals[key] = value
        }
        guard locals.count == function.params.count else {
            throw fail(arityMessage(function, given: locals.count))
        }
        guard frames.count < Self.maxDepth else {
            throw fail("Your functions called each other too many times (more than \(Self.maxDepth) deep).")
        }
        let callLine = line
        frames.append(Frame(function: function, locals: locals))
        defer {
            frames.removeLast()
            line = callLine
        }
        do {
            try exec(function.body)
        } catch Flow.ret {
            let value = returnValue
            returnValue = .none
            return value
        } catch Flow.brk, Flow.cont {
            throw fail("break and continue only work inside a loop.")
        }
        return .none
    }

    private func arityMessage(_ function: PyFunction, given: Int) -> String {
        let n = function.params.count
        let example = "\(function.name)(\(function.params.joined(separator: ", ")))"
        if n == 0 {
            return "\(function.name) doesn't take any values. Call it with empty ( ), like \(function.name)()."
        }
        return "\(function.name) needs \(n) value\(n == 1 ? "" : "s") inside ( ), like \(example). You gave it \(given)."
    }

    private func callMethod(_ receiver: Value, _ method: String, _ args: [Value]) throws -> Value {
        switch (receiver, method) {
        case (.list(let list), "append"):
            try arity(args, 1...1, "append", usage: "items.append(5)")
            guard list.items.count < Self.maxOutput else { throw fail("That list is too long!") }
            list.items.append(args[0])
            return .none
        case (.list(let list), "pop"):
            try arity(args, 0...1, "pop", usage: "items.pop()")
            guard !list.items.isEmpty else { throw fail("You can't pop from an empty list.") }
            let position = try args.first.map { try listPosition($0, count: list.items.count) } ?? list.items.count - 1
            return list.items.remove(at: position)
        case (.list(let list), "insert"):
            try arity(args, 2...2, "insert", usage: "items.insert(0, 5)")
            guard let i = args[0].integer else { throw fail("insert needs a position first, like items.insert(0, 5).") }
            let count = list.items.count
            list.items.insert(args[1], at: max(0, min(count, i < 0 ? count + i : i)))
            return .none
        case (.list(let list), "remove"):
            try arity(args, 1...1, "remove", usage: "items.remove(5)")
            guard let i = list.items.firstIndex(where: { $0.equals(args[0]) }) else {
                throw fail("\(args[0].repr) isn't in the list, so it can't be removed.")
            }
            list.items.remove(at: i)
            return .none
        case (.list(let list), "reverse"):
            list.items.reverse()
            return .none
        case (.list(let list), "index"):
            try arity(args, 1...1, "index", usage: "items.index(5)")
            guard let i = list.items.firstIndex(where: { $0.equals(args[0]) }) else {
                throw fail("\(args[0].repr) isn't in the list.")
            }
            return .int(i)
        case (.list(let list), "count"):
            try arity(args, 1...1, "count", usage: "items.count(5)")
            return .int(list.items.filter { $0.equals(args[0]) }.count)
        case (.str(let s), "upper"): return .str(s.uppercased())
        case (.str(let s), "lower"): return .str(s.lowercased())
        case (.str(let s), "title"): return .str(s.capitalized)
        case (.str(let s), "capitalize"): return .str(s.prefix(1).uppercased() + s.dropFirst().lowercased())
        case (.str(let s), "strip"): return .str(s.trimmingCharacters(in: .whitespaces))
        case (.str(let s), "replace"):
            try arity(args, 2...2, "replace", usage: "word.replace(\"a\", \"o\")")
            guard case .str(let old) = args[0], case .str(let new) = args[1], !old.isEmpty else {
                throw fail("replace needs two words, like word.replace(\"a\", \"o\").")
            }
            return .str(try limited(s.replacingOccurrences(of: old, with: new)))
        case (.str(let s), "count"):
            try arity(args, 1...1, "count", usage: "word.count(\"a\")")
            guard case .str(let part) = args[0], !part.isEmpty else { throw fail("count needs a word, like word.count(\"a\").") }
            return .int(s.components(separatedBy: part).count - 1)
        default:
            throw fail("Shelly doesn't know \(method) for \(receiver.kind).")
        }
    }

    // MARK: - Builtins

    static let turtleCommands: Set<String> = [
        "forward", "fd", "backward", "back", "bk", "left", "lt", "right", "rt",
        "penup", "pu", "up", "pendown", "pd", "down", "color", "pencolor", "fillcolor",
        "begin_fill", "end_fill", "pensize", "width", "goto", "setpos", "setposition", "setx", "sety",
        "setheading", "seth", "home", "circle", "dot", "write", "speed", "shape",
        "hideturtle", "ht", "showturtle", "st", "bgcolor", "xcor", "ycor", "heading",
        "done", "mainloop", "exitonclick", "title", "setup", "tracer", "update", "delay",
        "Turtle", "Screen",
    ]

    static let generalCommands: Set<String> = [
        "print", "range", "len", "str", "int", "float", "abs", "round", "min", "max", "sum",
        "input", "randint", "choice", "random", "sqrt", "list", "sorted", "type",
    ]

    static let globalBuiltins = turtleCommands.union(generalCommands)

    static let modules: [String: Set<String>] = [
        "turtle": turtleCommands,
        "random": ["randint", "choice", "random"],
        "math": ["sqrt", "pi", "floor", "ceil", "sin", "cos", "radians", "degrees"],
        "time": ["sleep"],
    ]

    private static func member(_ module: String, _ name: String) -> Value? {
        guard modules[module]?.contains(name) == true else { return nil }
        return name == "pi" ? .float(.pi) : .builtin(name)
    }

    static let usage: [String: String] = [
        "forward": "forward(50)", "fd": "fd(50)", "backward": "backward(50)", "back": "back(50)",
        "bk": "bk(50)", "left": "left(90)", "lt": "lt(90)", "right": "right(90)", "rt": "rt(90)",
        "goto": "goto(0, 100)", "setpos": "setpos(0, 100)", "setposition": "setposition(0, 100)",
        "setx": "setx(100)", "sety": "sety(100)", "setheading": "setheading(90)", "seth": "seth(90)",
        "circle": "circle(50)", "dot": "dot(20)", "color": "color(\"red\")", "pencolor": "pencolor(\"red\")",
        "fillcolor": "fillcolor(\"yellow\")", "bgcolor": "bgcolor(\"lightblue\")", "pensize": "pensize(5)",
        "width": "width(5)", "write": "write(\"Hello!\")", "range": "range(4)", "randint": "randint(1, 6)",
        "choice": "choice([\"red\", \"blue\"])", "len": "len(\"hello\")", "str": "str(5)", "int": "int(\"5\")",
        "float": "float(\"2.5\")", "abs": "abs(-5)", "round": "round(2.7)", "min": "min(3, 7)",
        "max": "max(3, 7)", "sum": "sum([1, 2, 3])", "sqrt": "sqrt(16)", "sleep": "sleep(1)",
        "floor": "floor(2.7)", "ceil": "ceil(2.1)", "sin": "sin(0)", "cos": "cos(0)",
        "radians": "radians(90)", "degrees": "degrees(3.14)", "list": "list(range(5))",
        "sorted": "sorted([3, 1, 2])", "speed": "speed(5)",
    ]

    private func arity(_ args: [Value], _ allowed: ClosedRange<Int>, _ name: String, usage: String? = nil) throws {
        guard !allowed.contains(args.count) else { return }
        let example = usage ?? Self.usage[name] ?? "\(name)()"
        if allowed.upperBound == 0 {
            throw fail("\(name) doesn't need anything inside ( ). Write it as \(name)().")
        }
        let count =
            allowed.lowerBound == allowed.upperBound
            ? "\(allowed.lowerBound) value\(allowed.lowerBound == 1 ? "" : "s")"
            : "\(allowed.lowerBound) to \(allowed.upperBound) values"
        throw fail("\(name) needs \(count) inside ( ), like \(example). You gave it \(args.count).")
    }

    private func number(_ value: Value, _ name: String) throws -> Double {
        if let d = value.number { return d }
        let example = Self.usage[name] ?? "\(name)(10)"
        if case .str(let s) = value, Double(s.trimmingCharacters(in: .whitespaces)) != nil {
            throw fail("\(name) needs a number, not a word. Take away the quotes: \(name)(\(s)).")
        }
        throw fail("\(name) needs a number, like \(example), but it got \(value.kind).")
    }

    private func integer(_ value: Value, _ name: String) throws -> Int {
        if let i = value.integer { return i }
        if case .float(let d) = value {
            throw fail("\(name) needs a whole number, not \(Value.format(d)). Try int(...) to drop the decimals.")
        }
        _ = try number(value, name)
        return 0
    }

    private func color(_ args: [Value], _ name: String) throws -> RGB {
        if args.count == 1, case .str(let text) = args[0] {
            if let rgb = RGB.parse(text) { return rgb }
            let suggestion = Suggest.closest(to: text.lowercased(), in: RGB.names.keys).map { " Did you mean \"\($0)\"?" } ?? ""
            throw fail(
                "Shelly doesn't know the color \"\(text)\".\(suggestion) Try red, orange, yellow, green, blue, purple or pink."
            )
        }
        var parts = args
        if args.count == 1, case .list(let list) = args[0] { parts = list.items }
        guard parts.count == 3 else {
            throw fail("\(name) needs a color name in quotes, like \(name)(\"red\").")
        }
        let values = try parts.map { try number($0, name) }
        let scale = values.contains { $0 > 1 } ? 255.0 : 1.0
        guard values.allSatisfy({ $0 >= 0 && $0 <= scale }) else {
            throw fail("Color numbers go from 0 to 255, like \(name)(255, 128, 0).")
        }
        return RGB(r: values[0] / scale, g: values[1] / scale, b: values[2] / scale)
    }

    private func record(_ event: TurtleEvent) throws {
        events.append(event)
        if events.count > Self.maxEvents {
            throw fail("Phew, Shelly is tired! That's more than \(Self.maxEvents.formatted()) moves. Try fewer.")
        }
    }

    private func move(to target: Point) throws {
        guard target.x.isFinite, target.y.isFinite, abs(target.x) < 100_000, abs(target.y) < 100_000 else {
            throw fail("That's too far for Shelly to walk!")
        }
        let clean = Point(x: (target.x * 1e9).rounded() / 1e9 + 0, y: (target.y * 1e9).rounded() / 1e9 + 0)
        let pen = turtle.penDown ? Pen(color: turtle.penColor, width: turtle.width) : nil
        try record(.move(from: turtle.position, to: clean, pen: pen))
        turtle.position = clean
        fillPath?.append(clean)
    }

    private func forward(_ distance: Double) throws {
        let radians = turtle.heading * .pi / 180
        try move(
            to: Point(
                x: turtle.position.x + distance * cos(radians),
                y: turtle.position.y + distance * sin(radians)
            )
        )
    }

    private func turn(by degrees: Double) throws {
        guard degrees.isFinite else { throw tooBig() }
        try setHeading(turtle.heading + degrees)
    }

    private func setHeading(_ heading: Double) throws {
        try record(.turn(from: turtle.heading, to: heading))
        turtle.heading = heading
    }

    /// Same steps as Python's turtle.circle, so drawings match real Python.
    private func circle(radius: Double, extent: Double, steps requested: Int?) throws {
        let fraction = abs(extent) / 360
        let steps = requested ?? 1 + Int(min(11 + abs(radius) / 6, 59) * fraction)
        guard steps > 0 else { return }
        var w = extent / Double(steps)
        var w2 = w / 2
        var length = 2 * radius * sin(w2 * .pi / 180)
        if radius < 0 {
            length = -length
            w = -w
            w2 = -w2
        }
        try turn(by: w2)
        for _ in 0..<steps {
            try forward(length)
            try turn(by: w)
        }
        try turn(by: -w2)
    }

    private func isNone(_ value: Value) -> Bool {
        if case .none = value { return true }
        return false
    }

    private func callBuiltin(_ name: String, _ args: [Value], _ kwargs: [String: Value], typed: String) throws -> Value {
        let allowedKeywords: Set<String> =
            switch name {
            case "print": ["sep", "end"]
            case "circle": ["extent", "steps"]
            case "write": ["align", "font", "move"]
            default: []
            }
        if let extra = kwargs.keys.first(where: { !allowedKeywords.contains($0) }) {
            throw fail("\(typed) doesn't understand \(extra)=. Leave it out.")
        }

        switch name {
        // Moving
        case "forward", "fd", "backward", "back", "bk":
            try arity(args, 1...1, typed)
            let distance = try number(args[0], typed)
            try forward(["forward", "fd"].contains(name) ? distance : -distance)
        case "left", "lt", "right", "rt":
            try arity(args, 1...1, typed)
            let degrees = try number(args[0], typed)
            try turn(by: ["left", "lt"].contains(name) ? degrees : -degrees)
        case "goto", "setpos", "setposition":
            var values = args
            if args.count == 1, case .list(let list) = args[0] { values = list.items }
            try arity(values, 2...2, typed)
            try move(to: Point(x: try number(values[0], typed), y: try number(values[1], typed)))
        case "setx":
            try arity(args, 1...1, typed)
            try move(to: Point(x: try number(args[0], typed), y: turtle.position.y))
        case "sety":
            try arity(args, 1...1, typed)
            try move(to: Point(x: turtle.position.x, y: try number(args[0], typed)))
        case "setheading", "seth":
            try arity(args, 1...1, typed)
            let target = try number(args[0], typed)
            var delta = (target - turtle.heading).truncatingRemainder(dividingBy: 360)
            if delta > 180 { delta -= 360 }
            if delta < -180 { delta += 360 }
            try turn(by: delta)
        case "home":
            try arity(args, 0...0, typed)
            try move(to: .zero)
            var delta = (-turtle.heading).truncatingRemainder(dividingBy: 360)
            if delta > 180 { delta -= 360 }
            if delta < -180 { delta += 360 }
            try turn(by: delta)
        case "circle":
            try arity(args, 1...3, typed)
            let radius = try number(args[0], typed)
            let extentValue = args.count > 1 ? args[1] : kwargs["extent"]
            var extent = 360.0
            if let extentValue, !isNone(extentValue) { extent = try number(extentValue, typed) }
            let stepsValue = args.count > 2 ? args[2] : kwargs["steps"]
            var steps: Int?
            if let stepsValue, !isNone(stepsValue) {
                let count = try integer(stepsValue, typed)
                guard (1...360).contains(count) else { throw fail("steps must be from 1 to 360.") }
                steps = count
            }
            guard abs(radius) <= 10_000, abs(extent) <= 3600 else { throw fail("That circle is too big for Shelly!") }
            try circle(radius: radius, extent: extent, steps: steps)

        // Pen
        case "penup", "pu", "up":
            try arity(args, 0...0, typed)
            turtle.penDown = false
        case "pendown", "pd", "down":
            try arity(args, 0...0, typed)
            turtle.penDown = true
        case "pensize", "width":
            try arity(args, 0...1, typed)
            guard let value = args.first else { return .float(turtle.width) }
            let size = try number(value, typed)
            guard size > 0, size <= 100 else { throw fail("Pen sizes go from 1 to 100, like pensize(5).") }
            turtle.width = size
        case "color":
            try arity(args, 1...3, typed)
            if args.count == 2 {
                turtle.penColor = try color([args[0]], typed)
                turtle.fillColor = try color([args[1]], typed)
            } else {
                let rgb = try color(args, typed)
                turtle.penColor = rgb
                turtle.fillColor = rgb
            }
        case "pencolor":
            try arity(args, 1...3, typed)
            turtle.penColor = try color(args, typed)
        case "fillcolor":
            try arity(args, 1...3, typed)
            turtle.fillColor = try color(args, typed)
        case "begin_fill":
            try arity(args, 0...0, typed)
            fillPath = [turtle.position]
        case "end_fill":
            try arity(args, 0...0, typed)
            guard let path = fillPath else {
                throw fail("Call begin_fill() before you draw the shape, then end_fill() after it.")
            }
            if path.count >= 3 { try record(.fill(path, turtle.fillColor)) }
            fillPath = nil
        case "dot":
            try arity(args, 0...2, typed)
            var size = max(turtle.width + 4, turtle.width * 2)
            var dotColor = turtle.penColor
            for arg in args {
                if case .str = arg {
                    dotColor = try color([arg], typed)
                } else {
                    size = try number(arg, typed)
                }
            }
            guard size > 0, size <= 400 else { throw fail("Dot sizes go from 1 to 400, like dot(20).") }
            try record(.dot(at: turtle.position, size: size, color: dotColor))
        case "write":
            try arity(args, 1...2, typed)
            try record(.write(String(args[0].text.prefix(200)), at: turtle.position, color: turtle.penColor))
        case "bgcolor":
            try arity(args, 1...3, typed)
            try record(.background(try color(args, typed)))
        case "hideturtle", "ht":
            try arity(args, 0...0, typed)
            turtle.visible = false
            try record(.visibility(false))
        case "showturtle", "st":
            try arity(args, 0...0, typed)
            turtle.visible = true
            try record(.visibility(true))

        // Questions about Shelly
        case "xcor":
            try arity(args, 0...0, typed)
            return .float(turtle.position.x)
        case "ycor":
            try arity(args, 0...0, typed)
            return .float(turtle.position.y)
        case "heading":
            try arity(args, 0...0, typed)
            let wrapped = turtle.heading.truncatingRemainder(dividingBy: 360)
            return .float(((wrapped < 0 ? wrapped + 360 : wrapped) * 1e9).rounded() / 1e9)

        // Real-Python turtle setup that Shelly doesn't need.
        case "speed", "shape", "done", "mainloop", "exitonclick", "title", "setup", "tracer", "update", "delay", "sleep":
            break
        case "Turtle", "Screen":
            return .module("turtle")

        // General Python
        case "print":
            let separator = kwargs["sep"].map(\.text) ?? " "
            let end = kwargs["end"].map(\.text) ?? "\n"
            let text = args.map(\.text).joined(separator: separator) + end
            guard output.count + text.count <= Self.maxOutput else {
                throw fail("That's a lot of printing! Shelly stopped after \(Self.maxOutput.formatted()) letters. Is there a loop that never stops?")
            }
            output += text
            try record(.print(text))
        case "input":
            throw fail(
                "Shelly can't ask questions yet. Put the answer straight into a variable instead, like name = \"Sam\"."
            )
        case "range":
            try arity(args, 1...3, typed)
            let values = try args.map { try integer($0, typed) }
            let (start, stop, step) =
                switch values.count {
                case 1: (0, values[0], 1)
                case 2: (values[0], values[1], 1)
                default: (values[0], values[1], values[2])
                }
            guard step != 0 else { throw fail("The step in range can't be 0, or the loop would never move.") }
            return .range(start, stop, step)
        case "len":
            try arity(args, 1...1, typed)
            switch args[0] {
            case .str(let s): return .int(s.count)
            case .list(let l): return .int(l.items.count)
            case .range(let a, let b, let c): return .int(Value.rangeCount(a, b, c))
            default: throw fail("len works on words and lists, not on \(args[0].kind).")
            }
        case "str":
            try arity(args, 0...1, typed)
            return .str(args.first?.text ?? "")
        case "int":
            try arity(args, 0...1, typed)
            guard let value = args.first else { return .int(0) }
            switch value {
            case .str(let s):
                guard let i = Int(s.trimmingCharacters(in: .whitespaces)) else {
                    throw fail("int can't turn \"\(s)\" into a whole number.")
                }
                return .int(i)
            case .float(let d):
                guard d.isFinite, abs(d) < 9e18 else { throw tooBig() }
                return .int(Int(d))
            default:
                return .int(try integer(value, typed))
            }
        case "float":
            try arity(args, 0...1, typed)
            guard let value = args.first else { return .float(0) }
            if case .str(let s) = value {
                guard let d = Double(s.trimmingCharacters(in: .whitespaces)) else {
                    throw fail("float can't turn \"\(s)\" into a number.")
                }
                return .float(d)
            }
            return .float(try number(value, typed))
        case "abs":
            try arity(args, 1...1, typed)
            if let i = args[0].integer { return .int(abs(i)) }
            return .float(abs(try number(args[0], typed)))
        case "round":
            try arity(args, 1...2, typed)
            let value = try number(args[0], typed)
            if args.count == 2 {
                let digits = try integer(args[1], typed)
                let factor = pow(10, Double(max(-10, min(10, digits))))
                return .float((value * factor).rounded(.toNearestOrEven) / factor)
            }
            let rounded = value.rounded(.toNearestOrEven)
            guard abs(rounded) < 9e18 else { throw tooBig() }
            return .int(Int(rounded))
        case "min", "max", "sum", "sorted", "list":
            var items = args
            if args.count == 1 {
                switch args[0] {
                case .list(let l): items = l.items
                case .range(let a, let b, let c):
                    guard Value.rangeCount(a, b, c) <= Self.maxOutput else { throw fail("That range is too long!") }
                    items = Array(stride(from: a, to: b, by: c)).map { .int($0) }
                case .str(let s) where name == "list" || name == "sorted": items = s.map { .str(String($0)) }
                default: break
                }
            }
            if name == "list" { return .list(PyList(items)) }
            if name == "sum" {
                return try items.reduce(Value.int(0)) { try binary("+", $0, $1) }
            }
            if name == "sorted" {
                var failure: PyError?
                let sorted = items.sorted { a, b in
                    do { return try compare("<", a, b) } catch {
                        failure = error as? PyError
                        return false
                    }
                }
                if let failure { throw failure }
                return .list(PyList(sorted))
            }
            guard var best = items.first else { throw fail("\(typed) needs at least one value, like \(typed)(3, 7).") }
            for item in items.dropFirst() where try compare(name == "min" ? "<" : ">", item, best) {
                best = item
            }
            return best
        case "type":
            try arity(args, 1...1, typed)
            return .str(args[0].kind)
        case "randint":
            try arity(args, 2...2, typed)
            let low = try integer(args[0], typed)
            let high = try integer(args[1], typed)
            guard low <= high else { throw fail("In randint(a, b), a can't be bigger than b.") }
            return .int(Int.random(in: low...high, using: &rng))
        case "choice":
            try arity(args, 1...1, typed)
            switch args[0] {
            case .list(let l) where !l.items.isEmpty: return l.items.randomElement(using: &rng)!
            case .str(let s) where !s.isEmpty: return .str(String(s.randomElement(using: &rng)!))
            default: throw fail("choice needs a list with something in it, like choice([\"red\", \"blue\"]).")
            }
        case "random":
            try arity(args, 0...0, typed)
            return .float(Double.random(in: 0..<1, using: &rng))
        case "sqrt":
            try arity(args, 1...1, typed)
            let value = try number(args[0], typed)
            guard value >= 0 else { throw fail("You can't take the square root of a negative number.") }
            return .float(value.squareRoot())
        case "floor", "ceil":
            try arity(args, 1...1, typed)
            let value = try number(args[0], typed).rounded(name == "floor" ? .down : .up)
            guard abs(value) < 9e18 else { throw tooBig() }
            return .int(Int(value))
        case "sin", "cos", "radians", "degrees":
            try arity(args, 1...1, typed)
            let value = try number(args[0], typed)
            switch name {
            case "sin": return .float(sin(value))
            case "cos": return .float(cos(value))
            case "radians": return .float(value * .pi / 180)
            default: return .float(value * 180 / .pi)
            }
        default:
            throw fail("Shelly doesn't know how to \(typed) yet.")
        }
        return .none
    }
}

/// A small seeded random number generator, so tests and level checks can repeat a run exactly.
nonisolated struct SplitMix: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
