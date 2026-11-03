import SwiftUI

/// What Shelly has printed so far in the replay.
struct OutputConsole: View {
    let text: String

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(text.isEmpty ? " " : text)
                    .font(.system(size: 18, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .id("end")
                    .accessibilityIdentifier("output")
            }
            .onChange(of: text) {
                proxy.scrollTo("end", anchor: .bottom)
            }
        }
        .background(Color(hex: 0x1F2433), in: .rect(cornerRadius: 16))
        .overlay(alignment: .topTrailing) {
            Label("Shelly says", systemImage: "bubble.left.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))
                .padding(8)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Output"))
        .accessibilityValue(Text(text.isEmpty ? String(localized: "Nothing printed yet") : text))
    }
}

#Preview {
    OutputConsole(text: "1\n2\n3\nBlast off!")
        .frame(height: 160)
        .padding()
}
