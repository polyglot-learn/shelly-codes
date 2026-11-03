import SwiftUI

struct LevelSuccess: Equatable {
    var stars: Int
    var shortCode: Bool
    var par: Int?
    var noHints: Bool
    var newShell: Shell?
    var next: Level?

    static func == (a: LevelSuccess, b: LevelSuccess) -> Bool {
        a.stars == b.stars && a.shortCode == b.shortCode && a.noHints == b.noHints && a.newShell == b.newShell
            && a.next?.id == b.next?.id
    }
}

/// The celebration after solving a level: stars, why they were earned, and what's next.
struct SuccessCard: View {
    let success: LevelSuccess
    let shell: Shell
    let next: () -> Void
    let playAgain: () -> Void
    @State private var shownStars = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            Confetti().ignoresSafeArea()
            VStack(spacing: 18) {
                Text("Level complete!")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .accessibilityIdentifier("successTitle")
                HStack(spacing: 14) {
                    ForEach(0..<3) { index in
                        Image(systemName: index < shownStars ? "star.fill" : "star")
                            .font(.system(size: 54, weight: .bold))
                            .foregroundStyle(index < shownStars ? Color(hex: 0xFFC233) : .gray.opacity(0.4))
                            .scaleEffect(index < shownStars ? 1 : 0.8)
                            .animation(.spring(response: 0.35, dampingFraction: 0.5), value: shownStars)
                    }
                }
                .accessibilityElement()
                .accessibilityLabel(Text("\(success.stars) of 3 stars"))

                VStack(alignment: .leading, spacing: 8) {
                    reason(true, String(localized: "Solved it!"))
                    if let par = success.par {
                        reason(success.shortCode, String(localized: "Short code: \(par) lines or fewer"))
                    } else {
                        reason(true, String(localized: "Any length of code"))
                    }
                    reason(success.noHints, String(localized: "No hints"))
                }
                .font(.system(size: 20, weight: .medium, design: .rounded))

                if let newShell = success.newShell {
                    HStack(spacing: 12) {
                        ShellyView(shell: newShell, heading: 0).frame(width: 60, height: 60)
                        Text("New shell unlocked: \(newShell.name)!")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                    }
                    .padding(12)
                    .background(Color(hex: newShell.colors.shell).opacity(0.15), in: .rect(cornerRadius: 14))
                }

                HStack(spacing: 14) {
                    Button(action: playAgain) {
                        Label("Play Again", systemImage: "arrow.counterclockwise")
                            .frame(minWidth: 150, minHeight: 50)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("playAgainButton")
                    if success.next != nil {
                        Button(action: next) {
                            Label("Next Level", systemImage: "arrow.right")
                                .frame(minWidth: 150, minHeight: 50)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: 0x2FBF71))
                        .accessibilityIdentifier("nextLevelButton")
                    }
                }
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .buttonBorderShape(.roundedRectangle(radius: 14))

                if success.next == nil {
                    Text("You finished every level! Keep making your own drawings in Free Draw.")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(32)
            .frame(maxWidth: 520)
            .background(.background, in: .rect(cornerRadius: 28))
            .shadow(radius: 20)
            .padding(24)
        }
        .task {
            for star in 1...success.stars {
                try? await Task.sleep(for: .milliseconds(AppEnvironment.isUITesting ? 0 : 280))
                shownStars = star
            }
        }
    }

    private func reason(_ earned: Bool, _ text: String) -> some View {
        Label {
            Text(text).foregroundStyle(earned ? .primary : .secondary)
        } icon: {
            Image(systemName: earned ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(earned ? Color(hex: 0x2FBF71) : .gray)
        }
    }
}

#Preview {
    SuccessCard(
        success: LevelSuccess(stars: 2, shortCode: false, par: 3, noHints: true, newShell: .ocean, next: nil),
        shell: .meadow, next: {}, playAgain: {}
    )
}
