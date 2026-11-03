import Foundation

nonisolated final class PyList {
    var items: [Value]

    init(_ items: [Value]) {
        self.items = items
    }
}

nonisolated final class PyFunction {
    let name: String
    let params: [String]
    let body: [Stmt]
    /// Names the function assigns to, which Python treats as local unless declared `global`.
    let localNames: Set<String>

    init(name: String, params: [String], body: [Stmt]) {
        self.name = name
        self.params = params
        self.body = body
        var names = Set(params)
        var globals: Set<String> = []
        PyFunction.collect(body, into: &names, globals: &globals)
        self.localNames = names.subtracting(globals)
    }

    private static func collect(_ stmts: [Stmt], into names: inout Set<String>, globals: inout Set<String>) {
        for stmt in stmts {
            switch stmt.kind {
            case .assign(.name(let name), _), .augAssign(.name(let name), _, _):
                names.insert(name)
            case .forLoop(let name, _, let body):
                names.insert(name)
                collect(body, into: &names, globals: &globals)
            case .whileLoop(_, let body):
                collect(body, into: &names, globals: &globals)
            case .ifs(let branches, let orelse):
                for branch in branches { collect(branch.body, into: &names, globals: &globals) }
                collect(orelse ?? [], into: &names, globals: &globals)
            case .def(let name, _, _):
                names.insert(name)
            case .global(let declared):
                globals.formUnion(declared)
            default:
                break
            }
        }
    }
}

nonisolated indirect enum Value {
    case int(Int)
    case float(Double)
    case str(String)
    case bool(Bool)
    case none
    case list(PyList)
    case range(Int, Int, Int)
    case function(PyFunction)
    case builtin(String)
    case module(String)
    case method(Value, String)

    /// How a child would describe the kind of value.
    var kind: String {
        switch self {
        case .int: "a whole number"
        case .float: "a decimal number"
        case .str: "a word (text)"
        case .bool: "True or False"
        case .none: "None (nothing)"
        case .list: "a list"
        case .range: "a range"
        case .function, .builtin, .method: "a command"
        case .module: "a module"
        }
    }

    var truthy: Bool {
        switch self {
        case .int(let i): i != 0
        case .float(let d): d != 0
        case .str(let s): !s.isEmpty
        case .bool(let b): b
        case .none: false
        case .list(let l): !l.items.isEmpty
        case .range(let start, let stop, let step): Value.rangeCount(start, stop, step) > 0
        default: true
        }
    }

    /// Python's str().
    var text: String {
        switch self {
        case .str(let s): s
        default: repr
        }
    }

    /// Python's repr().
    var repr: String {
        switch self {
        case .int(let i): String(i)
        case .float(let d): Value.format(d)
        case .str(let s): "'" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'") + "'"
        case .bool(let b): b ? "True" : "False"
        case .none: "None"
        case .list(let l): "[" + l.items.map(\.repr).joined(separator: ", ") + "]"
        case .range(let start, let stop, let step): step == 1 ? "range(\(start), \(stop))" : "range(\(start), \(stop), \(step))"
        case .function(let f): "<function \(f.name)>"
        case .builtin(let name): "<command \(name)>"
        case .module(let name): "<module \(name)>"
        case .method(_, let name): "<command \(name)>"
        }
    }

    static func format(_ d: Double) -> String {
        if d.isNaN { return "nan" }
        if d.isInfinite { return d > 0 ? "inf" : "-inf" }
        if d == d.rounded(), abs(d) < 1e16 {
            return String(format: "%.1f", d)
        }
        return d.description
    }

    static func rangeCount(_ start: Int, _ stop: Int, _ step: Int) -> Int {
        if step > 0 { return start < stop ? (stop - start + step - 1) / step : 0 }
        return start > stop ? (start - stop - step - 1) / -step : 0
    }

    /// Numbers (and True/False, which Python treats as 1 and 0) as a Double.
    var number: Double? {
        switch self {
        case .int(let i): Double(i)
        case .float(let d): d
        case .bool(let b): b ? 1 : 0
        default: nil
        }
    }

    var integer: Int? {
        switch self {
        case .int(let i): i
        case .bool(let b): b ? 1 : 0
        default: nil
        }
    }

    func equals(_ other: Value) -> Bool {
        switch (self, other) {
        case (.str(let a), .str(let b)): return a == b
        case (.none, .none): return true
        case (.list(let a), .list(let b)):
            return a.items.count == b.items.count && zip(a.items, b.items).allSatisfy { $0.equals($1) }
        case (.function(let a), .function(let b)): return a === b
        case (.builtin(let a), .builtin(let b)): return a == b
        case (.module(let a), .module(let b)): return a == b
        default:
            if let a = integer, let b = other.integer { return a == b }
            if let a = number, let b = other.number { return a == b }
            return false
        }
    }
}
