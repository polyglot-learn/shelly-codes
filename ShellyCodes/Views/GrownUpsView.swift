import SwiftData
import SwiftUI

/// The grown-ups area, behind a parental gate as Apple's Kids Category requires.
struct GrownUpsSheet: View {
    @State private var unlocked = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if unlocked {
                    GrownUpsView()
                } else {
                    ParentGate { unlocked = true }
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("doneButton")
                }
            }
        }
    }
}

/// A question most young children can't answer, so they don't change settings by accident.
struct ParentGate: View {
    let passed: () -> Void
    @State private var question = GateQuestion.make()
    @State private var answer = ""
    @State private var wrong = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color(hex: 0x3D8BFD))
            Text("Ask a grown-up")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
            Text("This area is for parents and teachers. To continue, answer:")
                .font(.system(size: 19, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("What is \(question.a) × \(question.b)?")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .accessibilityIdentifier("gateQuestion")
            TextField("Answer", text: $answer)
                .keyboardType(.numberPad)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .frame(width: 180)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit(check)
                .accessibilityIdentifier("gateAnswer")
            if wrong {
                Text("That's not right. Please ask a grown-up.")
                    .foregroundStyle(.red)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
            }
            Button("Continue", action: check)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(answer.isEmpty)
                .accessibilityIdentifier("gateContinue")
        }
        .padding(40)
        .frame(maxWidth: 520)
        .onAppear { focused = true }
    }

    private func check() {
        if Int(answer) == question.a * question.b {
            passed()
        } else {
            wrong = true
            answer = ""
            question = GateQuestion.make()
        }
    }
}

nonisolated struct GateQuestion: Equatable {
    var a: Int
    var b: Int

    static func make() -> GateQuestion {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") { return GateQuestion(a: 7, b: 8) }
        return GateQuestion(a: Int.random(in: 6...12), b: Int.random(in: 6...12))
    }
}

struct GrownUpsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var progress: [LevelProgress]
    @Query private var creations: [Creation]
    @AppStorage("unlockAll") private var unlockAll = false
    @AppStorage("shell") private var shell = Shell.meadow
    @State private var confirmReset = false
    @State private var confirmDeleteDrawings = false

    private var solvedCount: Int { Set(progress.filter(\.solved).map(\.levelID)).count }
    private var stars: Int {
        Dictionary(progress.map { ($0.levelID, $0.stars) }, uniquingKeysWith: max).values.reduce(0, +)
    }

    var body: some View {
        Form {
            Section("About Shelly Codes") {
                Text(
                    "Shelly Codes teaches Python to children aged 8 to 12. Each level is a short puzzle: kids write Python, tap Run, and watch Shelly the turtle follow their code. Mistakes get friendly explanations instead of error codes."
                )
                Text(
                    "Shelly understands a kid-sized part of Python 3: variables, numbers and text, lists, for and while loops, if/elif/else, functions with def, and the commands from Python's turtle module. Code is written exactly as in real Python, so it carries over."
                )
            }
            Section("Privacy") {
                Label("No ads, no in-app purchases", systemImage: "nosign")
                Label("No accounts and no sign-in", systemImage: "person.crop.circle.badge.xmark")
                Label("No tracking or analytics", systemImage: "eye.slash")
                Label("Works offline. Progress and drawings stay on this iPad.", systemImage: "ipad")
            }
            Section {
                Toggle("Unlock all levels", isOn: $unlockAll)
                    .accessibilityIdentifier("unlockAllToggle")
            } header: {
                Text("Levels")
            } footer: {
                Text("Levels normally open one at a time. Turn this on to jump ahead, for example in a classroom.")
            }
            Section("Progress") {
                LabeledContent("Levels solved", value: "\(solvedCount) of \(Curriculum.levels.count)")
                LabeledContent("Stars", value: "\(stars) of \(Curriculum.maxStars)")
                LabeledContent("Saved drawings", value: "\(creations.count)")
                Button("Reset All Progress", role: .destructive) { confirmReset = true }
                Button("Delete All Drawings", role: .destructive) { confirmDeleteDrawings = true }
                    .disabled(creations.isEmpty)
            }
            Section {
                LabeledContent("Version", value: Self.version)
            }
        }
        .navigationTitle("Grown-ups")
        .confirmationDialog("Reset all progress?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset Progress", role: .destructive) {
                for record in progress { modelContext.delete(record) }
                shell = .meadow
            }
        } message: {
            Text("All stars, solved levels and level code will be erased. Drawings are kept.")
        }
        .confirmationDialog("Delete all drawings?", isPresented: $confirmDeleteDrawings, titleVisibility: .visible) {
            Button("Delete Drawings", role: .destructive) {
                for creation in creations { modelContext.delete(creation) }
            }
        } message: {
            Text("This can't be undone.")
        }
    }

    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}

#Preview {
    GrownUpsSheet()
        .modelContainer(for: [LevelProgress.self, Creation.self], inMemory: true)
}
