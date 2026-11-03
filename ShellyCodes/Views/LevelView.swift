import SwiftData
import SwiftUI

/// Shows one level, and moves on to the next level in place when the child taps "Next level".
struct LevelHost: View {
    @State var levelID: String

    var body: some View {
        if let level = Curriculum.level(levelID) {
            LevelView(level: level) { next in
                levelID = next.id
            }
            .id(levelID)
        }
    }
}

struct LevelView: View {
    let level: Level
    let goToLevel: (Level) -> Void

    @Environment(\.modelContext) private var modelContext
    @Query private var records: [LevelProgress]
    @AppStorage("speed") private var speed = PlaybackSpeed.normal
    @AppStorage("shell") private var shell = Shell.meadow

    @State private var code: String
    @State private var playback = Playback()
    @State private var editor = EditorController()
    @State private var bubble: Bubble
    @State private var hintsShown = 0
    @State private var errorLine: Int?
    @State private var collected: [Int: Int] = [:]
    @State private var runTask: Task<Void, Never>?
    @State private var success: LevelSuccess?
    @State private var confirmStartOver = false
    @State private var mistakes = 0
    @State private var loaded = false
    private let target: RunResult
    private let ghost: [(Point, Point)]

    init(level: Level, goToLevel: @escaping (Level) -> Void) {
        self.level = level
        self.goToLevel = goToLevel
        let id = level.id
        _records = Query(filter: #Predicate<LevelProgress> { $0.levelID == id })
        _code = State(initialValue: level.starter)
        _bubble = State(initialValue: .story(level.story))
        let target = level.target
        self.target = target
        ghost = level.checksDrawing ? Drawing(target.events).segments : []
    }

    var body: some View {
        Workspace {
            SpeechBubble(bubble: bubble, shell: shell)
        } editor: {
            EditorPanel(code: $code, errorLine: errorLine, chips: level.chips, controller: editor) {
                RunButton(isPlaying: playback.isPlaying, run: run, skip: playback.skipToEnd)
                if !level.hints.isEmpty {
                    Button(action: showHint) {
                        Label(hintLabel, systemImage: "lightbulb.fill")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .frame(minHeight: 56)
                            .padding(.horizontal, 6)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color(hex: 0xF5B700))
                    .buttonBorderShape(.roundedRectangle(radius: 16))
                    .accessibilityIdentifier("hintButton")
                }
            }
        } stage: {
            Stage(
                playback: playback, stars: level.stars, starsCollectedAt: collected, ghost: ghost,
                shell: shell, showsOutput: level.checksOutput || !playback.events.allSatisfy { !$0.isPrint }
            )
        }
        .background(Color(hex: 0xF3F6FB))
        .navigationTitle("\(level.id)  \(level.title)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                SpeedMenu(speed: $speed)
                Button("Start Over", systemImage: "arrow.counterclockwise") {
                    confirmStartOver = true
                }
                .accessibilityIdentifier("startOverButton")
            }
        }
        .confirmationDialog("Start this level over?", isPresented: $confirmStartOver, titleVisibility: .visible) {
            Button("Start Over", role: .destructive, action: startOver)
        } message: {
            Text("Your code for this level will go back to how it started.")
        }
        .overlay {
            if let success {
                SuccessCard(success: success, shell: shell) {
                    self.success = nil
                    if let next = success.next { goToLevel(next) }
                } playAgain: {
                    self.success = nil
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.spring(duration: 0.35), value: success != nil)
        .sensoryFeedback(.success, trigger: success != nil) { _, shown in shown }
        .sensoryFeedback(.warning, trigger: mistakes)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let saved = records.first?.code, !saved.isEmpty { code = saved }
            playback.reset(to: level.start)
        }
        .onChange(of: code) {
            errorLine = nil
            save(code: code)
        }
        .onDisappear {
            runTask?.cancel()
        }
    }

    private var hintLabel: String {
        hintsShown == 0 ? String(localized: "Hint") : String(localized: "Hint \(hintsShown)/\(level.hints.count)")
    }

    private func run() {
        editor.endEditing()
        runTask?.cancel()
        let result = Interpreter.run(code, start: level.start)
        collected = LevelChecker.collectedStars(level.stars, in: result.events)
        errorLine = nil
        if case .hint = bubble {} else { bubble = .story(level.story) }
        runTask = Task {
            await playback.play(result.events, from: level.start, speed: speed, instant: AppEnvironment.isUITesting)
            guard !Task.isCancelled else { return }
            finish(result)
        }
    }

    private func finish(_ result: RunResult) {
        switch LevelChecker.check(level, result, target: target) {
        case .error(let error):
            errorLine = error.line
            bubble = .error(error)
            mistakes += 1
        case .notYet(let message):
            bubble = .feedback(message)
            mistakes += 1
        case .solved:
            solved()
        }
    }

    private func solved() {
        let stars = LevelChecker.rating(level, code: code, hintsUsed: hintsShown)
        let all = (try? modelContext.fetch(FetchDescriptor<LevelProgress>())) ?? []
        let before = all.reduce(0) { $0 + $1.stars }
        let record = progressRecord()
        let previousBest = record.stars
        record.stars = max(record.stars, stars)
        record.solved = true
        record.code = code
        let after = before - previousBest + record.stars
        let newShell = Shell.allCases.first { !$0.isUnlocked(stars: before) && $0.isUnlocked(stars: after) }
        bubble = .story(level.story)
        success = LevelSuccess(
            stars: stars,
            shortCode: level.par.map { codeLineCount(code) <= $0 } ?? true,
            par: level.par,
            noHints: hintsShown == 0,
            newShell: newShell,
            next: Curriculum.next(after: level)
        )
    }

    /// Shows the next hint; after the last one, tapping again cycles back to the first.
    private func showHint() {
        let next: Int
        if case .hint(let shown, _) = bubble {
            next = shown % level.hints.count + 1
        } else {
            next = min(hintsShown + 1, level.hints.count)
        }
        hintsShown = max(hintsShown, next)
        bubble = .hint(next, level.hints[next - 1])
    }

    private func startOver() {
        runTask?.cancel()
        code = level.starter
        errorLine = nil
        collected = [:]
        bubble = .story(level.story)
        playback.reset(to: level.start)
    }

    private func progressRecord() -> LevelProgress {
        if let record = records.first { return record }
        let record = LevelProgress(levelID: level.id, code: code)
        modelContext.insert(record)
        return record
    }

    private func save(code: String) {
        if let record = records.first {
            record.code = code
        } else if code != level.starter {
            modelContext.insert(LevelProgress(levelID: level.id, code: code))
        }
    }
}

extension TurtleEvent {
    var isPrint: Bool {
        if case .print = self { return true }
        return false
    }
}

#Preview {
    NavigationStack {
        LevelHost(levelID: "3.1")
    }
    .modelContainer(for: [LevelProgress.self, Creation.self], inMemory: true)
}
