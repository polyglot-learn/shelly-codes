import SwiftUI
import UIKit

/// Lets buttons outside the editor insert code at the cursor.
@Observable
final class EditorController {
    @ObservationIgnored fileprivate weak var textView: UITextView?
    @ObservationIgnored fileprivate var onChange: ((String) -> Void)?

    func endEditing() {
        textView?.resignFirstResponder()
    }

    /// Inserts a code chip. Whole commands go on their own line with the right indent;
    /// small pieces like `*` or `"green"` go exactly where the cursor is.
    func insert(_ snippet: String) {
        guard let textView else { return }
        let text = textView.text as NSString
        let editing = textView.isFirstResponder
        var selection = editing ? textView.selectedRange : NSRange(location: text.length, length: 0)
        if selection.location > text.length { selection = NSRange(location: text.length, length: 0) }

        let lineRange = text.lineRange(for: NSRange(location: selection.location, length: 0))
        var lineContentRange = lineRange
        if lineContentRange.length > 0, text.substring(with: lineRange).hasSuffix("\n") {
            lineContentRange.length -= 1
        }
        let line = text.substring(with: lineContentRange)
        let indent = String(line.prefix { $0 == " " })
        let isBlank = line.trimmingCharacters(in: .whitespaces).isEmpty
        let isCommand = snippet.first.map { $0.isLetter || $0 == "_" } ?? false
        let cursorAtLineEnd = selection.location >= lineContentRange.location + lineContentRange.length
            || text.substring(
                with: NSRange(
                    location: selection.location,
                    length: lineContentRange.location + lineContentRange.length - selection.location)
            ).trimmingCharacters(in: .whitespaces).isEmpty

        var range: NSRange
        var insertion: String
        if isBlank {
            range = lineContentRange
            insertion = (line.isEmpty && lineRange.location > 0 ? indentAfter(text, before: lineRange.location) : indent)
                + snippet
        } else if !isCommand || selection.length > 0 || !cursorAtLineEnd {
            range = selection
            insertion = snippet
        } else {
            range = NSRange(location: lineContentRange.location + lineContentRange.length, length: 0)
            let nextIndent = line.trimmingCharacters(in: .whitespaces).hasSuffix(":") ? indent + "    " : indent
            insertion = "\n" + nextIndent + snippet
        }
        if isCommand, snippet.hasSuffix(":") {
            let blockIndent = String(insertion.drop { $0 == "\n" }.prefix { $0 == " " })
            insertion += "\n" + blockIndent + "    "
        }
        replace(range, with: insertion, in: textView)
    }

    /// The indent a new line should get, from the line above it.
    private func indentAfter(_ text: NSString, before location: Int) -> String {
        let previous = text.lineRange(for: NSRange(location: location - 1, length: 0))
        let line = text.substring(with: previous).trimmingCharacters(in: .newlines)
        let indent = String(line.prefix { $0 == " " })
        return line.trimmingCharacters(in: .whitespaces).hasSuffix(":") ? indent + "    " : indent
    }

    fileprivate func replace(_ range: NSRange, with string: String, in textView: UITextView) {
        let updated = (textView.text as NSString).replacingCharacters(in: range, with: string)
        textView.text = updated
        textView.selectedRange = NSRange(location: range.location + (string as NSString).length, length: 0)
        onChange?(updated)
    }
}

struct CodeEditor: UIViewRepresentable {
    @Binding var text: String
    var errorLine: Int?
    var controller: EditorController
    var fontSize: CGFloat = 21

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        textView.spellCheckingType = .no
        textView.inlinePredictionType = .no
        textView.keyboardType = .asciiCapable
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 14, left: 8, bottom: 14, right: 8)
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive
        textView.accessibilityIdentifier = "codeEditor"
        textView.accessibilityLabel = String(localized: "Python code")
        textView.text = text
        context.coordinator.highlight(textView)
        textView.selectedRange = NSRange(location: (text as NSString).length, length: 0)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        controller.textView = textView
        controller.onChange = { [weak coordinator, weak textView] updated in
            guard let coordinator, let textView else { return }
            coordinator.parent.text = updated
            coordinator.highlight(textView)
        }
        if textView.text != text {
            textView.text = text
            coordinator.highlight(textView)
        } else if coordinator.highlightedErrorLine != errorLine || coordinator.highlightedFontSize != fontSize {
            coordinator.highlight(textView)
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: CodeEditor
        var highlightedErrorLine: Int?
        var highlightedFontSize: CGFloat = 0

        init(_ parent: CodeEditor) {
            self.parent = parent
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            // The tap that focuses the editor can leave the caret at the very start. Children
            // nearly always mean to add code at the end, so put it there instead.
            DispatchQueue.main.async {
                if textView.selectedRange == NSRange(location: 0, length: 0), textView.text.count > 0 {
                    textView.selectedRange = NSRange(location: (textView.text as NSString).length, length: 0)
                }
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            highlight(textView)
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText string: String) -> Bool {
            let text = textView.text as NSString
            if string == "\n" {
                // Keep the indent, and add 4 spaces after a line ending in a colon.
                let lineStart = text.lineRange(for: NSRange(location: range.location, length: 0)).location
                let before = text.substring(with: NSRange(location: lineStart, length: range.location - lineStart))
                var indent = String(before.prefix { $0 == " " })
                if before.trimmingCharacters(in: .whitespaces).hasSuffix(":") { indent += "    " }
                parent.controller.replace(range, with: "\n" + indent, in: textView)
                return false
            }
            if string == "\t" {
                parent.controller.replace(range, with: "    ", in: textView)
                return false
            }
            if string.isEmpty, range.length == 1 {
                // Backspace in the indent removes a whole level of 4 spaces.
                let lineStart = text.lineRange(for: NSRange(location: range.location, length: 0)).location
                let before = text.substring(with: NSRange(location: lineStart, length: range.location + 1 - lineStart))
                if before.count >= 4, before.allSatisfy({ $0 == " " }) {
                    let width = before.count % 4 == 0 ? 4 : before.count % 4
                    parent.controller.replace(
                        NSRange(location: range.location + 1 - width, length: width), with: "", in: textView)
                    return false
                }
            }
            return true
        }

        func highlight(_ textView: UITextView) {
            guard textView.markedTextRange == nil else { return }
            let size = parent.fontSize
            highlightedErrorLine = parent.errorLine
            highlightedFontSize = size
            let storage = textView.textStorage
            let full = NSRange(location: 0, length: storage.length)
            let font = UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
            let bold = UIFont.monospacedSystemFont(ofSize: size, weight: .bold)
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 4

            storage.beginEditing()
            storage.setAttributes(
                [.font: font, .foregroundColor: UIColor.label, .paragraphStyle: paragraph], range: full)
            for token in SyntaxColors.tokens(in: storage.string) {
                storage.addAttribute(.foregroundColor, value: token.kind.color, range: token.range)
                if token.kind == .keyword { storage.addAttribute(.font, value: bold, range: token.range) }
            }
            if let line = parent.errorLine, let range = SyntaxColors.range(ofLine: line, in: storage.string) {
                storage.addAttribute(.backgroundColor, value: UIColor.systemRed.withAlphaComponent(0.18), range: range)
            }
            storage.endEditing()
            textView.typingAttributes = [.font: font, .foregroundColor: UIColor.label, .paragraphStyle: paragraph]
        }
    }
}
