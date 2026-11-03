import SwiftData
import SwiftUI

struct ContentView: View {
    @State private var path: [Route] = []
    @AppStorage("welcomed") private var welcomed = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack(path: $path) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .level(let id): LevelHost(levelID: id)
                    case .freeDraw: CreationsView(path: $path)
                    case .creation(let creation): CreationView(creation: creation)
                    case .shells: ShellsView()
                    }
                }
        }
        // An overlay, not a fullScreenCover: after a cover is dismissed, the code editor
        // could no longer become first responder on first launch.
        .overlay {
            if !welcomed {
                WelcomeView {
                    withAnimation(.easeOut(duration: 0.3)) { welcomed = true }
                }
                .transition(.opacity)
            }
        }
        #if DEBUG
            .onAppear {
                if let mode = ScreenshotMode.current { path = mode.prepare(modelContext) }
            }
        #endif
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [LevelProgress.self, Creation.self], inMemory: true)
}
