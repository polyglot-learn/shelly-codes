import SwiftUI

/// Code on one side and Shelly's canvas on the other in landscape; canvas on top in portrait.
struct Workspace<Header: View, Editor: View, Stage: View>: View {
    @ViewBuilder var header: Header
    @ViewBuilder var editor: Editor
    @ViewBuilder var stage: Stage

    /// Decided from the size without the keyboard. If the keyboard could flip the layout,
    /// SwiftUI would rebuild the code editor and it would lose focus as soon as it got it.
    @State private var landscape = false

    var body: some View {
        GeometryReader { geometry in
            if landscape {
                HStack(spacing: 16) {
                    VStack(spacing: 12) {
                        header
                        editor
                    }
                    .frame(width: geometry.size.width * 0.45)
                    stage
                }
            } else {
                VStack(spacing: 12) {
                    header
                    stage.frame(height: geometry.size.height * 0.46)
                    editor
                }
            }
        }
        .padding(16)
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onAppear { landscape = Self.isLandscape(geometry.size) }
                    .onChange(of: geometry.size) { landscape = Self.isLandscape(geometry.size) }
            }
            .ignoresSafeArea(.keyboard)
        }
    }

    static func isLandscape(_ size: CGSize) -> Bool {
        size.width > size.height * 1.05
    }
}

/// The chips, the code and the buttons under it.
struct EditorPanel<Buttons: View>: View {
    @Binding var code: String
    var errorLine: Int?
    var chips: [String]
    var controller: EditorController
    @ViewBuilder var buttons: Buttons

    var body: some View {
        VStack(spacing: 10) {
            if !chips.isEmpty {
                ChipBar(chips: chips) { controller.insert($0) }
            }
            CodeEditor(text: $code, errorLine: errorLine, controller: controller)
                .background(.background, in: .rect(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.black.opacity(0.08)))
            HStack(spacing: 12) {
                buttons
            }
        }
    }
}

/// The canvas with its output console underneath when the program prints.
struct Stage: View {
    let playback: Playback
    var stars: [Point] = []
    var starsCollectedAt: [Int: Int] = [:]
    var ghost: [(Point, Point)] = []
    var shell: Shell
    var showsOutput: Bool

    var body: some View {
        VStack(spacing: 12) {
            let progress = playback.progress
            TurtleCanvas(
                events: playback.events, progress: progress, pose: playback.pose,
                stars: stars, starsCollectedAt: starsCollectedAt, ghost: ghost, shell: shell
            )
            .clipShape(.rect(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.black.opacity(0.08)))
            .accessibilityElement()
            .accessibilityLabel(Text("Shelly's drawing"))
            .accessibilityValue(Text(canvasDescription(done: progress.done)))
            .accessibilityIdentifier("canvas")

            if showsOutput {
                OutputConsole(text: printed(upTo: progress.done))
                    .frame(height: 150)
            }
        }
    }

    private func printed(upTo done: Int) -> String {
        var text = ""
        for case .print(let chunk) in playback.events.prefix(done) { text += chunk }
        return text
    }

    private func canvasDescription(done: Int) -> String {
        let lines = Drawing(playback.events.prefix(done)).segments.count
        var parts = [String(localized: "Shelly drew \(lines) lines.")]
        if !stars.isEmpty {
            let got = starsCollectedAt.values.filter { $0 < done }.count
            parts.append(String(localized: "\(got) of \(stars.count) stars collected."))
        }
        return parts.joined(separator: " ")
    }
}

/// The big green Run button. While Shelly is moving it becomes Skip.
struct RunButton: View {
    let isPlaying: Bool
    let run: () -> Void
    let skip: () -> Void

    var body: some View {
        Button(action: isPlaying ? skip : run) {
            Label(isPlaying ? "Skip" : "Run", systemImage: isPlaying ? "forward.end.fill" : "play.fill")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.borderedProminent)
        .tint(isPlaying ? Color(hex: 0x3D8BFD) : Color(hex: 0x2FBF71))
        .buttonBorderShape(.roundedRectangle(radius: 16))
        .keyboardShortcut("r", modifiers: .command)
        .accessibilityIdentifier("runButton")
    }
}

/// Picks how fast Shelly walks.
struct SpeedMenu: View {
    @Binding var speed: PlaybackSpeed

    var body: some View {
        Menu {
            Picker("Speed", selection: $speed) {
                ForEach(PlaybackSpeed.allCases) { speed in
                    Label(speed.label, systemImage: speed.symbol).tag(speed)
                }
            }
        } label: {
            Label("Speed", systemImage: speed.symbol)
        }
        .accessibilityIdentifier("speedMenu")
    }
}
