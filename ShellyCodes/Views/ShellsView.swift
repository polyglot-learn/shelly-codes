import SwiftData
import SwiftUI

/// Shell colors to unlock with stars.
struct ShellsView: View {
    @Query private var progress: [LevelProgress]
    @AppStorage("shell") private var selected = Shell.meadow

    private var stars: Int {
        Dictionary(progress.map { ($0.levelID, $0.stars) }, uniquingKeysWith: max).values.reduce(0, +)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Label("\(stars) of \(Curriculum.maxStars) stars", systemImage: "star.fill")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: 0xE09B00))
                    if let next = Shell.nextLocked(stars: stars) {
                        Text("Collect \(next.starsNeeded - stars) more stars to unlock the \(next.name) shell!")
                            .font(.system(size: 19, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("You unlocked every shell. Amazing!")
                            .font(.system(size: 19, weight: .medium, design: .rounded))
                    }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 20)], spacing: 20) {
                    ForEach(Shell.allCases) { shell in
                        shellCard(shell)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(Color(hex: 0xF3F6FB))
        .navigationTitle("Shelly's Shells")
    }

    private func shellCard(_ shell: Shell) -> some View {
        let unlocked = shell.isUnlocked(stars: stars)
        let isSelected = shell == selected
        return Button {
            selected = shell
        } label: {
            VStack(spacing: 10) {
                ShellyView(shell: shell, heading: 90)
                    .frame(width: 110, height: 110)
                    .saturation(unlocked ? 1 : 0)
                    .opacity(unlocked ? 1 : 0.45)
                Text(shell.name)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                if isSelected {
                    Label("Wearing", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color(hex: 0x2FBF71))
                } else if unlocked {
                    Text("Tap to wear")
                        .foregroundStyle(.secondary)
                } else {
                    Label("\(shell.starsNeeded) stars", systemImage: "lock.fill")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .frame(maxWidth: .infinity, minHeight: 210)
            .background(.background, in: .rect(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(isSelected ? Color(hex: 0x2FBF71) : .clear, lineWidth: 4)
            )
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
        .accessibilityLabel(
            Text(unlocked ? "\(shell.name) shell" : "\(shell.name) shell, locked, needs \(shell.starsNeeded) stars")
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
