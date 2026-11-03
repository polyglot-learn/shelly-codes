import SwiftData
import SwiftUI

/// Free drawing: the same workspace as a level, with no goal.
struct CreationView: View {
    @Bindable var creation: Creation
    @AppStorage("speed") private var speed = PlaybackSpeed.normal
    @AppStorage("shell") private var shell = Shell.meadow
    @State private var playback = Playback()
    @State private var editor = EditorController()
    @State private var bubble = Bubble.story(
        String(localized: "Draw anything! Try `bgcolor(\"black\")`, `dot(30)`, `begin_fill()` or `randint(1, 100)`.")
    )
    @State private var errorLine: Int?
    @State private var runTask: Task<Void, Never>?

    static let chips = [
        "forward(100)", "left(90)", "right(90)", "for i in range(4):", "color(\"red\")", "circle(50)",
        "penup()", "pendown()", "goto(0, 0)", "begin_fill()", "end_fill()", "dot(20)", "pensize(5)",
        "bgcolor(\"lightblue\")", "randint(1, 100)", "write(\"Hi!\")", "def shape():",
    ]

    var body: some View {
        Workspace {
            SpeechBubble(bubble: bubble, shell: shell)
        } editor: {
            EditorPanel(code: $creation.code, errorLine: errorLine, chips: Self.chips, controller: editor) {
                RunButton(isPlaying: playback.isPlaying, run: run, skip: playback.skipToEnd)
            }
        } stage: {
            Stage(
                playback: playback, shell: shell,
                showsOutput: playback.events.contains { $0.isPrint }
            )
        }
        .background(Color(hex: 0xF3F6FB))
        .navigationTitle($creation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarRole(.editor)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                SpeedMenu(speed: $speed)
            }
        }
        .onChange(of: creation.code) {
            errorLine = nil
            creation.updatedAt = .now
        }
        .onAppear {
            run()
        }
        .onDisappear {
            runTask?.cancel()
        }
    }

    private func run() {
        editor.endEditing()
        runTask?.cancel()
        let result = Interpreter.run(creation.code)
        errorLine = nil
        runTask = Task {
            await playback.play(result.events, from: TurtleState(), speed: speed, instant: AppEnvironment.isUITesting)
            guard !Task.isCancelled else { return }
            if let error = result.error {
                errorLine = error.line
                bubble = .error(error)
            } else if case .error = bubble {
                bubble = .story(String(localized: "You fixed it! Keep going."))
            }
        }
    }
}
