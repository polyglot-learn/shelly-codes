import Foundation

/// A recursive-descent parser for the Python that Shelly understands.
nonisolated struct Parser {
    private var tokens: [Token]
    private var pos = 0

    static func parse(_ source: String) throws -> [Stmt] {
        var parser = Parser(tokens: try Lexer.tokenize(source))
        return try parser.program()
    }

    private init(tokens: [Token]) {
        self.tokens = tokens
    }

    // MARK: - Token helpers

    private var peek: Tok { tokens[pos].tok }
    private var line: Int { tokens[pos].line }
    private var previous: Tok? { pos > 0 ? tokens[pos - 1].tok : nil }

    @discardableResult
    private mutating func advance() -> Token {
        let token = tokens[pos]
        if pos < tokens.count - 1 { pos += 1 }
        return token
    }

    private mutating func accept(_ tok: Tok) -> Bool {
        guard peek == tok else { return false }
        advance()
        return true
    }

    private func isOp(_ op: String) -> Bool { peek == .op(op) }
    private func isKeyword(_ word: String) -> Bool { peek == .keyword(word) }
    private var atLineEnd: Bool { peek == .newline || peek == .eof || peek == .dedent }

    private func fail(_ message: String) -> PyError {
        PyError(line: line, message: message)
    }

    // MARK: - Statements

    private mutating func program() throws -> [Stmt] {
        var body: [Stmt] = []
        while peek != .eof {
            if peek == .indent {
                throw fail(
                    "This line is pushed in with spaces, but it isn't inside a loop, if or def. Remove the spaces at the start."
                )
            }
            if accept(.newline) || accept(.dedent) { continue }
            body.append(try statement())
        }
        return body
    }

    private mutating func statement() throws -> Stmt {
        let line = self.line
        switch peek {
        case .keyword("if"):
            return try ifStatement()
        case .keyword("while"):
            advance()
            let condition = try header("while")
            return Stmt(kind: .whileLoop(condition, try block("while")), line: line)
        case .keyword("for"):
            advance()
            guard case .name(let variable) = peek else {
                throw fail("After for, write a name for the counter, like: for i in range(4):")
            }
            advance()
            guard accept(.keyword("in")) else {
                throw fail("A for loop looks like this: for i in range(4):")
            }
            let iterable = try header("for")
            return Stmt(kind: .forLoop(variable, iterable, try block("for")), line: line)
        case .keyword("def"):
            return try function()
        case .keyword("elif"), .keyword("else"):
            throw fail("This \(keywordText) needs an if right above it, lined up at the same indent.")
        default:
            let stmt = try simpleStatement()
            try endOfLine()
            return stmt
        }
    }

    private var keywordText: String {
        if case .keyword(let word) = peek { return word }
        return ""
    }

    private mutating func function() throws -> Stmt {
        let line = self.line
        advance()
        guard case .name(let name) = peek else {
            throw fail("After def, give your function a name, like: def square():")
        }
        advance()
        guard accept(.op("(")) else {
            throw fail("A function name needs ( ) after it, like: def \(name)():")
        }
        var params: [String] = []
        if !accept(.op(")")) {
            repeat {
                if isOp(")") { break }
                guard case .name(let param) = peek else {
                    throw fail("Inside def \(name)( ), list names for the values it gets, like: def \(name)(size):")
                }
                if params.contains(param) {
                    throw fail("The name \(param) is used twice inside def \(name)( ). Give each one a different name.")
                }
                advance()
                params.append(param)
            } while accept(.op(","))
            guard accept(.op(")")) else {
                throw fail("Separate the names inside def \(name)( ) with commas, like: def \(name)(size, color):")
            }
        }
        return Stmt(kind: .def(name, params, try block("def")), line: line)
    }

    private mutating func ifStatement() throws -> Stmt {
        let line = self.line
        advance()
        let condition = try header("if")
        var branches = [Branch(condition: condition, body: try block("if"))]
        var orelse: [Stmt]?
        while true {
            if isKeyword("elif") {
                advance()
                let condition = try header("elif")
                branches.append(Branch(condition: condition, body: try block("elif")))
            } else if isKeyword("else") {
                advance()
                if isKeyword("if") {
                    throw fail("In Python, write elif instead of else if.")
                }
                orelse = try block("else")
                break
            } else {
                break
            }
        }
        return Stmt(kind: .ifs(branches, orelse), line: line)
    }

    /// The expression after if/while/for ... in, which must be followed by a colon.
    private mutating func header(_ keyword: String) throws -> Expr {
        let expr = try expression()
        if isOp("=") {
            throw fail(
                "To check if two things are equal, use == (two equals signs). One = puts a value into a variable."
            )
        }
        if !isOp(":") {
            throw fail("Add a colon : at the end of this \(keyword) line.")
        }
        return expr
    }

    private mutating func block(_ keyword: String) throws -> [Stmt] {
        guard accept(.op(":")) else {
            throw fail("Add a colon : at the end of this \(keyword) line.")
        }
        if !atLineEnd {
            let stmt = try simpleStatement()
            try endOfLine()
            return [stmt]
        }
        _ = accept(.newline)
        guard accept(.indent) else {
            throw fail(
                "The lines inside this \(keyword) need to be pushed in (indented) with 4 spaces, so Shelly knows they belong to it."
            )
        }
        var body: [Stmt] = []
        while peek != .dedent && peek != .eof {
            if peek == .indent {
                throw fail("This line is pushed in more than the line above it. Make them line up.")
            }
            if accept(.newline) { continue }
            body.append(try statement())
        }
        _ = accept(.dedent)
        return body
    }

    private mutating func simpleStatement() throws -> Stmt {
        let line = self.line
        switch peek {
        case .keyword("pass"):
            advance()
            return Stmt(kind: .pass, line: line)
        case .keyword("break"):
            advance()
            return Stmt(kind: .brk, line: line)
        case .keyword("continue"):
            advance()
            return Stmt(kind: .cont, line: line)
        case .keyword("return"):
            advance()
            return Stmt(kind: .ret(atLineEnd ? nil : try expression()), line: line)
        case .keyword("import"):
            advance()
            let module = try moduleName()
            var alias = module
            if accept(.keyword("as")) {
                guard case .name(let name) = advance().tok else {
                    throw fail("After as, write a short name, like: import turtle as t")
                }
                alias = name
            }
            return Stmt(kind: .importModule(module, alias: alias), line: line)
        case .keyword("from"):
            advance()
            let module = try moduleName()
            guard accept(.keyword("import")) else {
                throw fail("Write it like this: from \(module) import *")
            }
            if accept(.op("*")) {
                return Stmt(kind: .fromImport(module, names: nil), line: line)
            }
            var names: [String] = []
            repeat {
                guard case .name(let name) = advance().tok else {
                    throw fail("After import, list the names you want, like: from random import randint")
                }
                names.append(name)
            } while accept(.op(","))
            return Stmt(kind: .fromImport(module, names: names), line: line)
        case .keyword("global"):
            advance()
            var names: [String] = []
            repeat {
                guard case .name(let name) = advance().tok else {
                    throw fail("After global, write the variable's name, like: global score")
                }
                names.append(name)
            } while accept(.op(","))
            return Stmt(kind: .global(names), line: line)
        case .keyword(let word) where ["True", "False", "None", "not"].contains(word) == false:
            throw fail("\(word) is a special Python word and can't start a line here.")
        default:
            break
        }

        let target = try expression()
        if accept(.op("=")) {
            try checkAssignable(target)
            let value = try expression()
            if isOp("=") {
                throw fail("Put only one = on a line, like size = 50.")
            }
            return Stmt(kind: .assign(target, value), line: line)
        }
        for op in ["+=", "-=", "*=", "/=", "//=", "%=", "**="] where accept(.op(op)) {
            try checkAssignable(target)
            return Stmt(kind: .augAssign(target, String(op.dropLast()), try expression()), line: line)
        }
        return Stmt(kind: .expr(target), line: line)
    }

    private mutating func moduleName() throws -> String {
        guard case .name(var name) = advance().tok else {
            throw fail("Write the name of a module, like: import random")
        }
        while accept(.op(".")) {
            guard case .name(let part) = advance().tok else { break }
            name += "." + part
        }
        return name
    }

    private func checkAssignable(_ target: Expr) throws {
        switch target {
        case .name, .index:
            return
        case .call:
            throw fail("You can't put a value into a command. To make a variable, write a name, like size = 50.")
        default:
            throw fail("You can only put a value into a variable name, like size = 50.")
        }
    }

    private mutating func endOfLine() throws {
        if accept(.newline) || peek == .eof || peek == .dedent { return }
        throw unexpected()
    }

    /// The friendliest explanation we can find for a token that doesn't belong.
    private func unexpected() -> PyError {
        if let misspelled = misspelledKeywordOnLine() {
            return fail("Did you mean \(misspelled)? Check the spelling at the start of this line.")
        }
        if case .name(let previousName) = previous {
            switch peek {
            case .int, .float:
                return fail("Commands need ( ) around their number, like \(previousName)(100).")
            case .string:
                return fail("Commands need ( ) around what you give them, like \(previousName)(\"hello\").")
            default:
                break
            }
        }
        switch peek {
        case .op(":"):
            return fail("This line doesn't need a colon : here. Only lines starting with if, for, while or def end in :")
        case .op("="):
            return fail("Shelly can't put a value here. To make a variable, start the line with its name, like size = 50.")
        case .op(")"), .op("]"):
            return fail("There's an extra \(describe(peek)) here.")
        case .indent:
            return fail("This line is pushed in more than the line above it. Make them line up.")
        default:
            return fail("Shelly doesn't understand \(describe(peek)) here. Is something missing between the words?")
        }
    }

    private func misspelledKeywordOnLine() -> String? {
        var start = pos
        while start > 0, tokens[start - 1].line == line, tokens[start - 1].tok != .newline,
            tokens[start - 1].tok != .indent, tokens[start - 1].tok != .dedent
        {
            start -= 1
        }
        guard case .name(let first) = tokens[start].tok, first.count >= 2 else { return nil }
        let blockWords = ["if", "elif", "else", "while", "for", "def", "return", "import"]
        return Suggest.closest(to: first, in: blockWords)
    }

    private func describe(_ tok: Tok) -> String {
        switch tok {
        case .name(let name): "the name \(name)"
        case .keyword(let word): "the word \(word)"
        case .int(let value): "the number \(value)"
        case .float(let value): "the number \(value)"
        case .string(let text): "the text \"\(text)\""
        case .op(let op): op
        case .newline, .eof, .dedent: "the end of the line"
        case .indent: "the spaces"
        }
    }

    // MARK: - Expressions

    private mutating func expression() throws -> Expr {
        try orExpr()
    }

    private mutating func orExpr() throws -> Expr {
        var left = try andExpr()
        while accept(.keyword("or")) {
            left = .or(left, try andExpr())
        }
        return left
    }

    private mutating func andExpr() throws -> Expr {
        var left = try notExpr()
        while accept(.keyword("and")) {
            left = .and(left, try notExpr())
        }
        return left
    }

    private mutating func notExpr() throws -> Expr {
        if accept(.keyword("not")) {
            return .unary("not", try notExpr())
        }
        return try comparison()
    }

    private mutating func comparison() throws -> Expr {
        let first = try arith()
        var rest: [Comparison] = []
        while true {
            if case .op(let op) = peek, ["==", "!=", "<", ">", "<=", ">="].contains(op) {
                advance()
                rest.append(Comparison(op: op, right: try arith()))
            } else if accept(.keyword("in")) {
                rest.append(Comparison(op: "in", right: try arith()))
            } else if isKeyword("not"), pos + 1 < tokens.count, tokens[pos + 1].tok == .keyword("in") {
                advance()
                advance()
                rest.append(Comparison(op: "not in", right: try arith()))
            } else {
                break
            }
        }
        return rest.isEmpty ? first : .compare(first, rest)
    }

    private mutating func arith() throws -> Expr {
        var left = try term()
        while case .op(let op) = peek, op == "+" || op == "-" {
            advance()
            left = .binary(op, left, try term())
        }
        return left
    }

    private mutating func term() throws -> Expr {
        var left = try factor()
        while case .op(let op) = peek, ["*", "/", "//", "%"].contains(op) {
            advance()
            left = .binary(op, left, try factor())
        }
        return left
    }

    private mutating func factor() throws -> Expr {
        if case .op(let op) = peek, op == "-" || op == "+" {
            advance()
            return .unary(op, try factor())
        }
        return try power()
    }

    private mutating func power() throws -> Expr {
        let base = try postfix()
        if accept(.op("**")) {
            return .binary("**", base, try factor())
        }
        return base
    }

    private mutating func postfix() throws -> Expr {
        var expr = try atom()
        while true {
            if accept(.op("(")) {
                expr = try callArguments(expr)
            } else if accept(.op("[")) {
                let index = try expression()
                if isOp(":") {
                    throw fail("Shelly can't cut lists with : yet. Use one position, like items[0].")
                }
                guard accept(.op("]")) else { throw fail("Close the [ with a ].") }
                expr = .index(expr, index)
            } else if accept(.op(".")) {
                guard case .name(let name) = advance().tok else {
                    throw fail("After a dot, write a name, like random.randint.")
                }
                expr = .attribute(expr, name)
            } else {
                return expr
            }
        }
    }

    private mutating func callArguments(_ callee: Expr) throws -> Expr {
        var args: [Expr] = []
        var kwargs: [KeywordArgument] = []
        while !isOp(")") {
            if case .name(let name) = peek, pos + 1 < tokens.count, tokens[pos + 1].tok == .op("=") {
                advance()
                advance()
                kwargs.append(KeywordArgument(name: name, value: try expression()))
            } else {
                if !kwargs.isEmpty {
                    throw fail("Put the plain values first and the name=value ones last.")
                }
                args.append(try expression())
            }
            if accept(.op(",")) { continue }
            if isOp("=") {
                throw fail("Inside ( ), use == to compare. One = is only for name=value.")
            }
            guard isOp(")") else {
                throw fail("Separate the values inside ( ) with commas, like goto(50, 100).")
            }
        }
        advance()
        return .call(callee, args, kwargs)
    }

    private mutating func atom() throws -> Expr {
        let token = advance()
        switch token.tok {
        case .int(let value): return .int(value)
        case .float(let value): return .float(value)
        case .string(var text):
            while case .string(let more) = peek {
                advance()
                text += more
            }
            return .string(text)
        case .keyword("True"): return .bool(true)
        case .keyword("False"): return .bool(false)
        case .keyword("None"): return .none
        case .name(let name): return .name(name)
        case .op("("):
            let inner = try expression()
            if isOp(",") {
                throw fail("Shelly doesn't know ( , ) groups. Use a list with [ ] instead, like [1, 2, 3].")
            }
            guard accept(.op(")")) else { throw fail("Close the ( with a ).") }
            return inner
        case .op("["):
            var items: [Expr] = []
            while !isOp("]") {
                items.append(try expression())
                if accept(.op(",")) { continue }
                guard isOp("]") else {
                    throw fail("Separate the things in a list with commas, like [1, 2, 3].")
                }
            }
            advance()
            return .list(items)
        case .newline, .eof, .dedent:
            throw PyError(line: token.line, message: "This line ends too early. Something is missing at the end.")
        case .keyword(let word):
            throw PyError(line: token.line, message: "\(word) is a special Python word and can't go here.")
        case .op(let op):
            throw PyError(line: token.line, message: "Shelly expected a number, a word or a name before \(op).")
        case .indent:
            throw PyError(line: token.line, message: "Shelly doesn't understand this line.")
        }
    }
}
