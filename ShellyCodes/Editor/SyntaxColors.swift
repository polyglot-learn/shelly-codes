import UIKit

/// Finds the parts of a program to color. Works on unfinished code, line by line, and never fails.
nonisolated enum SyntaxColors {
    enum Kind: Equatable {
        case keyword, command, number, string, comment
    }

    struct Token: Equatable {
        var kind: Kind
        var range: NSRange
    }

    static func tokens(in text: String) -> [Token] {
        let chars = Array(text.utf16)
        var tokens: [Token] = []
        var i = 0

        func isLetter(_ c: UInt16) -> Bool {
            (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95 || c > 127
        }
        func isDigit(_ c: UInt16) -> Bool { c >= 48 && c <= 57 }

        while i < chars.count {
            let c = chars[i]
            if c == 35 {  // #
                var j = i
                while j < chars.count, chars[j] != 10 { j += 1 }
                tokens.append(Token(kind: .comment, range: NSRange(location: i, length: j - i)))
                i = j
            } else if c == 34 || c == 39 || c == 0x201C || c == 0x201D {  // quotes
                let closing: Set<UInt16> = c == 39 ? [39] : [34, 0x201C, 0x201D]
                var j = i + 1
                while j < chars.count, !closing.contains(chars[j]), chars[j] != 10 {
                    if chars[j] == 92 { j += 1 }  // backslash escape
                    j += 1
                }
                let end = min(j + 1, chars.count)
                tokens.append(Token(kind: .string, range: NSRange(location: i, length: end - i)))
                i = end
            } else if isDigit(c) {
                var j = i
                while j < chars.count, isDigit(chars[j]) || chars[j] == 46 { j += 1 }
                tokens.append(Token(kind: .number, range: NSRange(location: i, length: j - i)))
                i = j
            } else if isLetter(c) {
                var j = i
                while j < chars.count, isLetter(chars[j]) || isDigit(chars[j]) { j += 1 }
                let word = String(utf16CodeUnits: Array(chars[i..<j]), count: j - i)
                if Lexer.keywords.contains(word) {
                    tokens.append(Token(kind: .keyword, range: NSRange(location: i, length: j - i)))
                } else if Interpreter.globalBuiltins.contains(word) {
                    tokens.append(Token(kind: .command, range: NSRange(location: i, length: j - i)))
                }
                i = j
            } else {
                i += 1
            }
        }
        return tokens
    }

    /// The range of a 1-based line number.
    static func range(ofLine line: Int, in text: String) -> NSRange? {
        let ns = text as NSString
        var current = 1
        var location = 0
        while current < line {
            let next = ns.range(of: "\n", range: NSRange(location: location, length: ns.length - location))
            guard next.location != NSNotFound else { return nil }
            location = next.location + 1
            current += 1
        }
        guard location <= ns.length else { return nil }
        let end = ns.range(of: "\n", range: NSRange(location: location, length: ns.length - location))
        return NSRange(location: location, length: (end.location == NSNotFound ? ns.length : end.location) - location)
    }
}

extension SyntaxColors.Kind {
    var color: UIColor {
        switch self {
        case .keyword: UIColor(red: 0.62, green: 0.19, blue: 0.80, alpha: 1)
        case .command: UIColor(red: 0.10, green: 0.42, blue: 0.85, alpha: 1)
        case .number: UIColor(red: 0.85, green: 0.42, blue: 0.0, alpha: 1)
        case .string: UIColor(red: 0.10, green: 0.56, blue: 0.25, alpha: 1)
        case .comment: UIColor.secondaryLabel
        }
    }
}
