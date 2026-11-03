import Foundation

/// A mistake in a program, explained in words an 8-year-old can follow.
nonisolated struct PyError: Error, Equatable, Sendable {
    var line: Int
    var message: String
}

nonisolated enum Tok: Equatable, Sendable {
    case name(String)
    case keyword(String)
    case int(Int)
    case float(Double)
    case string(String)
    case op(String)
    case newline, indent, dedent, eof
}

nonisolated struct Token: Equatable, Sendable {
    var tok: Tok
    var line: Int
}

/// Turns source text into tokens, including Python's INDENT and DEDENT.
nonisolated enum Lexer {
    static let keywords: Set<String> = [
        "if", "elif", "else", "while", "for", "in", "def", "return", "break", "continue",
        "pass", "and", "or", "not", "True", "False", "None", "import", "from", "as", "global",
    ]

    private static let twoCharOps: Set<String> = [
        "**", "//", "==", "!=", "<=", ">=", "+=", "-=", "*=", "/=", "%=",
    ]
    private static let threeCharOps: Set<String> = ["//=", "**="]
    private static let oneCharOps = Set("()[]{},:.+-*/%=<>")

    /// Fixes characters that iPad keyboards and copy-paste sneak into code.
    static func normalize(_ source: String) -> String {
        var text = source.replacingOccurrences(of: "\r\n", with: "\n")
        let replacements: [(String, String)] = [
            ("\r", "\n"), ("\u{201C}", "\""), ("\u{201D}", "\""), ("\u{201E}", "\""),
            ("\u{2018}", "'"), ("\u{2019}", "'"), ("\u{00A0}", " "), ("\t", "    "),
            ("\u{2014}", "-"), ("\u{2013}", "-"), ("\u{00D7}", "*"), ("\u{00F7}", "/"),
        ]
        for (from, to) in replacements {
            text = text.replacingOccurrences(of: from, with: to)
        }
        return text
    }

    static func tokenize(_ source: String) throws -> [Token] {
        var tokens: [Token] = []
        var indents = [0]
        var brackets: [(char: Character, line: Int)] = []
        let lines = normalize(source).split(separator: "\n", omittingEmptySubsequences: false)

        for (index, rawLine) in lines.enumerated() {
            let line = index + 1
            let chars = Array(rawLine)
            var i = 0

            if brackets.isEmpty {
                while i < chars.count, chars[i] == " " { i += 1 }
                if i == chars.count || chars[i] == "#" { continue }
                if i > indents[indents.count - 1] {
                    indents.append(i)
                    tokens.append(Token(tok: .indent, line: line))
                } else {
                    while i < indents[indents.count - 1] {
                        indents.removeLast()
                        tokens.append(Token(tok: .dedent, line: line))
                    }
                    if i != indents[indents.count - 1] {
                        throw PyError(
                            line: line,
                            message:
                                "The spaces at the start of this line don't line up with the lines above it. Make it line up exactly."
                        )
                    }
                }
            }

            while i < chars.count {
                let c = chars[i]
                if c == " " {
                    i += 1
                    continue
                }
                if c == "#" { break }

                if isDigit(c) || (c == "." && i + 1 < chars.count && isDigit(chars[i + 1])) {
                    let (tok, end) = try number(chars, from: i, line: line)
                    tokens.append(Token(tok: tok, line: line))
                    i = end
                    continue
                }

                if c.isLetter || c == "_" {
                    var j = i
                    while j < chars.count, chars[j].isLetter || isDigit(chars[j]) || chars[j] == "_" { j += 1 }
                    let word = String(chars[i..<j])
                    tokens.append(Token(tok: keywords.contains(word) ? .keyword(word) : .name(word), line: line))
                    i = j
                    continue
                }

                if c == "\"" || c == "'" {
                    let (text, end) = try string(chars, from: i, line: line)
                    tokens.append(Token(tok: .string(text), line: line))
                    i = end
                    continue
                }

                let three = i + 2 < chars.count ? String(chars[i...i + 2]) : ""
                let two = i + 1 < chars.count ? String(chars[i...i + 1]) : ""
                if threeCharOps.contains(three) {
                    tokens.append(Token(tok: .op(three), line: line))
                    i += 3
                } else if twoCharOps.contains(two) {
                    tokens.append(Token(tok: .op(two), line: line))
                    i += 2
                } else if oneCharOps.contains(c) {
                    if "([{".contains(c) { brackets.append((c, line)) }
                    if ")]}".contains(c) {
                        guard let open = brackets.popLast() else {
                            throw PyError(line: line, message: "There's an extra \(c) here that has nothing to close.")
                        }
                        if c != closing(open.char) {
                            throw PyError(
                                line: line,
                                message: "This \(c) doesn't match the \(open.char) it's closing. Use \(closing(open.char)) instead."
                            )
                        }
                    }
                    tokens.append(Token(tok: .op(String(c)), line: line))
                    i += 1
                } else if c == "!" {
                    throw PyError(line: line, message: "Python doesn't use ! on its own. To check \"not equal\", write !=.")
                } else {
                    throw PyError(line: line, message: "Shelly doesn't know what the symbol \(c) means here.")
                }
            }

            if brackets.isEmpty {
                tokens.append(Token(tok: .newline, line: line))
            }
        }

        if let open = brackets.last {
            throw PyError(
                line: open.line,
                message: "This \(open.char) is never closed. Add a \(closing(open.char)) to match it."
            )
        }
        let last = max(lines.count, 1)
        while indents.count > 1 {
            indents.removeLast()
            tokens.append(Token(tok: .dedent, line: last))
        }
        tokens.append(Token(tok: .eof, line: last))
        return tokens
    }

    private static func isDigit(_ c: Character) -> Bool {
        c.isASCII && c.isNumber
    }

    private static func closing(_ open: Character) -> Character {
        switch open {
        case "(": ")"
        case "[": "]"
        default: "}"
        }
    }

    private static func number(_ chars: [Character], from start: Int, line: Int) throws -> (Tok, Int) {
        var j = start
        var isFloat = false
        var seenExponent = false
        while j < chars.count {
            let d = chars[j]
            if isDigit(d) || d == "_" {
                j += 1
            } else if d == "." && !isFloat && !seenExponent {
                isFloat = true
                j += 1
            } else if (d == "e" || d == "E") && !seenExponent, j + 1 < chars.count,
                isDigit(chars[j + 1])
                    || ((chars[j + 1] == "-" || chars[j + 1] == "+") && j + 2 < chars.count && isDigit(chars[j + 2]))
            {
                seenExponent = true
                isFloat = true
                j += 2
            } else {
                break
            }
        }
        if j < chars.count, chars[j].isLetter || chars[j] == "_" {
            throw PyError(
                line: line,
                message: "Names can't start with a number, and numbers can't have letters stuck to them. Try a space or a different name."
            )
        }
        let text = String(chars[start..<j]).replacingOccurrences(of: "_", with: "")
        if isFloat {
            guard let value = Double(text) else {
                throw PyError(line: line, message: "Shelly can't read the number \(text).")
            }
            return (.float(value), j)
        }
        guard let value = Int(text) else {
            throw PyError(line: line, message: "That number is too big for Shelly!")
        }
        return (.int(value), j)
    }

    private static func string(_ chars: [Character], from start: Int, line: Int) throws -> (String, Int) {
        let quote = chars[start]
        var j = start + 1
        var text = ""
        while j < chars.count {
            let d = chars[j]
            if d == "\\", j + 1 < chars.count {
                switch chars[j + 1] {
                case "n": text.append("\n")
                case "t": text.append("    ")
                case "\\": text.append("\\")
                case "'": text.append("'")
                case "\"": text.append("\"")
                default:
                    text.append("\\")
                    text.append(chars[j + 1])
                }
                j += 2
                continue
            }
            if d == quote { return (text, j + 1) }
            text.append(d)
            j += 1
        }
        throw PyError(
            line: line,
            message: "This text is missing its closing \(quote). Words need quotes on both sides, like \(quote)hello\(quote)."
        )
    }
}
