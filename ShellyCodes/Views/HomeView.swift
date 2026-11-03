import SwiftData
import SwiftUI

enum Route: Hashable {
    case level(String)
    case freeDraw
    case creation(Creation)
    case shells
}

/// The level map: chapters, stars, what to play next, and the way into Free Draw.
struct HomeView: View {
    @Query private var progress: [LevelProgress]
    @AppStorage("shell") private var shell = Shell.meadow
    @AppStorage("unlockAll") private var unlockAll = false
    @State private var showingGrownUps = false

    private var solved: Set<String> {
        Set(progress.filter(\.solved).map(\.levelID))
    }

    private var starsByLevel: [String: Int] {
        Dictionary(progress.map { ($0.levelID, $0.stars) }, uniquingKeysWith: max)
    }

    private var totalStars: Int {
        starsByLevel.values.reduce(0, +)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                if let next = Unlocks.nextUp(solved: solved, unlockAll: unlockAll) {
                    continueCard(next)
                }
                freeDrawCard
                ForEach(Curriculum.chapters) { chapter in
                    chapterCard(chapter)
                }
            }
            .padding(24)
            .frame(maxWidth: 920)
            .frame(maxWidth: .infinity)
        }
        .background(Color(hex: 0xF3F6FB))
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingGrownUps) {
            GrownUpsSheet()
        }
    }

    private var header: some View {
        HStack(spacing: 18) {
            NavigationLink(value: Route.shells) {
                ShellyView(shell: shell, heading: 20)
                    .frame(width: 96, height: 96)
            }
            .accessibilityLabel(Text("Shelly's shells"))
            VStack(alignment: .leading, spacing: 4) {
                Text("Shelly Codes")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                Text("Learn real Python, one step at a time")
                    .font(.system(size: 19, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            NavigationLink(value: Route.shells) {
                Label("\(totalStars)", systemImage: "star.fill")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: 0xE09B00))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(hex: 0xFFC233).opacity(0.2), in: .capsule)
            }
            .accessibilityLabel(Text("\(totalStars) stars. Shelly's shells"))
            .accessibilityIdentifier("starsButton")
            Button {
                showingGrownUps = true
            } label: {
                Label("Grown-ups", systemImage: "lock.fill")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("grownUpsButton")
        }
    }

    private func continueCard(_ level: Level) -> some View {
        let chapter = Curriculum.chapters[level.chapterNumber - 1]
        return NavigationLink(value: Route.level(level.id)) {
            HStack(spacing: 20) {
                Image(systemName: "play.fill")
                    .font(.system(size: 34, weight: .heavy))
                    .frame(width: 76, height: 76)
                    .background(.white.opacity(0.25), in: .circle)
                VStack(alignment: .leading, spacing: 4) {
                    Text(solved.isEmpty ? "Start here" : "Next up")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .opacity(0.85)
                    Text("\(level.id)  \(level.title)")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                }
                Spacer()
                Image(systemName: chapter.symbol)
                    .font(.system(size: 50))
                    .opacity(0.35)
            }
            .foregroundStyle(.white)
            .padding(24)
            .background(Color(hex: chapter.colorHex).gradient, in: .rect(cornerRadius: 28))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("continueButton")
    }

    private var freeDrawCard: some View {
        NavigationLink(value: Route.freeDraw) {
            HStack(spacing: 16) {
                Image(systemName: "paintbrush.pointed.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(Color(hex: 0xE5468C).gradient, in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Free Draw")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                    Text("Make anything you like with Python")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(20)
            .background(.background, in: .rect(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("freeDrawButton")
    }

    private func chapterCard(_ chapter: Chapter) -> some View {
        let color = Color(hex: chapter.colorHex)
        let earned = chapter.levels.reduce(0) { $0 + (starsByLevel[$1.id] ?? 0) }
        return VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: chapter.symbol)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(color.gradient, in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Chapter \(chapter.id)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                    Text(chapter.title)
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                    Text(chapter.subtitle)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Label("\(earned)/\(chapter.levels.count * 3)", systemImage: "star.fill")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: 0xE09B00))
            }
            HStack(alignment: .top, spacing: 12) {
                ForEach(chapter.levels) { level in
                    levelBubble(level, color: color)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(22)
        .background(.background, in: .rect(cornerRadius: 28))
    }

    private func levelBubble(_ level: Level, color: Color) -> some View {
        let unlocked = Unlocks.isUnlocked(level.id, solved: solved, unlockAll: unlockAll)
        let stars = starsByLevel[level.id] ?? 0
        return NavigationLink(value: Route.level(level.id)) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(unlocked ? AnyShapeStyle(color.gradient) : AnyShapeStyle(Color.gray.opacity(0.2)))
                    if unlocked {
                        Text("\(level.number)")
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.gray)
                    }
                }
                .frame(width: 76, height: 76)
                Text(level.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(unlocked ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                HStack(spacing: 2) {
                    ForEach(0..<3) { index in
                        Image(systemName: index < stars ? "star.fill" : "star")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(index < stars ? Color(hex: 0xFFC233) : .gray.opacity(0.35))
                    }
                }
            }
            .frame(width: 140)
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
        .accessibilityLabel(
            Text(
                unlocked
                    ? "Level \(level.id), \(level.title), \(stars) of 3 stars"
                    : "Level \(level.id), \(level.title), locked"
            )
        )
        .accessibilityIdentifier("level-\(level.id)")
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .modelContainer(for: [LevelProgress.self, Creation.self], inMemory: true)
}
