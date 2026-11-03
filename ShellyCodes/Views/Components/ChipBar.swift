import SwiftUI

/// Tappable code pieces, so children can build programs without typing every letter.
struct ChipBar: View {
    let chips: [String]
    let insert: (String) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(chips, id: \.self) { chip in
                    Button {
                        insert(chip)
                    } label: {
                        Text(chip)
                            .font(.system(size: 18, weight: .semibold, design: .monospaced))
                            .lineLimit(1)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.accentColor.opacity(0.14), in: .rect(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.accentColor.opacity(0.35)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Insert \(chip)"))
                    .accessibilityIdentifier("chip-\(chip)")
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }
}

#Preview {
    ChipBar(chips: ["for i in range(4):", "forward(100)", "left(90)"]) { _ in }
        .padding()
}
