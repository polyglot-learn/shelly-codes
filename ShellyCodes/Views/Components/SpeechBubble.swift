import SwiftUI

/// What Shelly is saying to the child: the level story, a hint, feedback or an error.
enum Bubble: Equatable {
    case story(String)
    case hint(Int, String)
    case feedback(String)
    case error(PyError)

    var tint: Color {
        switch self {
        case .story: Color(hex: 0x2FBF71)
        case .hint: Color(hex: 0xF5B700)
        case .feedback: Color(hex: 0xFF8A3D)
        case .error: Color(hex: 0xE5484D)
        }
    }

    var title: String? {
        switch self {
        case .story: nil
        case .hint(let number, _): String(localized: "Hint \(number)")
        case .feedback: String(localized: "Not quite yet")
        case .error(let error): String(localized: "Oops! Line \(error.line)")
        }
    }

    var symbol: String? {
        switch self {
        case .story: nil
        case .hint: "lightbulb.fill"
        case .feedback: "arrow.uturn.backward.circle.fill"
        case .error: "ladybug.fill"
        }
    }

    var message: String {
        switch self {
        case .story(let text), .hint(_, let text), .feedback(let text): text
        case .error(let error): error.message
        }
    }
}

struct SpeechBubble: View {
    let bubble: Bubble
    let shell: Shell

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ShellyView(shell: shell, heading: 0)
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 6) {
                if let title = bubble.title {
                    Label(title, systemImage: bubble.symbol ?? "info.circle")
                        .font(.headline)
                        .foregroundStyle(bubble.tint)
                }
                Text(LocalizedStringKey(bubble.message))
                    .font(.system(size: 19, weight: .medium, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("bubbleMessage")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.background, in: .rect(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(bubble.tint, lineWidth: 3))
        }
        .animation(.spring(duration: 0.3), value: bubble)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: 20) {
        SpeechBubble(bubble: .story("Tap **Run** and I'll walk to the star! `forward(100)`"), shell: .meadow)
        SpeechBubble(bubble: .hint(1, "Add left(90) inside the loop."), shell: .ocean)
        SpeechBubble(bubble: .error(PyError(line: 2, message: "Add a colon : at the end of this for line.")), shell: .berry)
    }
    .padding()
    .background(Color.paper)
}
