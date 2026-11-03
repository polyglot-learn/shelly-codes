import Foundation
import Testing

@testable import ShellyCodes

struct EditorTests {
    @Test func syntaxColorsFindEachKind() {
        let code = "for i in range(4):  # loop\n    color(\"red\")\n    size = 10.5"
        let kinds = SyntaxColors.tokens(in: code).map(\.kind)
        #expect(kinds == [.keyword, .keyword, .command, .number, .comment, .command, .string, .number])
    }

    @Test func unfinishedTextNeverCrashes() {
        for code in ["\"unclosed", "'", "#", "print(\u{201C}hi", "é = 1", ""] {
            _ = SyntaxColors.tokens(in: code)
        }
    }

    @Test func lineRanges() {
        let text = "one\ntwo\n\nfour"
        #expect(SyntaxColors.range(ofLine: 1, in: text) == NSRange(location: 0, length: 3))
        #expect(SyntaxColors.range(ofLine: 2, in: text) == NSRange(location: 4, length: 3))
        #expect(SyntaxColors.range(ofLine: 3, in: text) == NSRange(location: 8, length: 0))
        #expect(SyntaxColors.range(ofLine: 4, in: text) == NSRange(location: 9, length: 4))
        #expect(SyntaxColors.range(ofLine: 9, in: text) == nil)
    }
}
