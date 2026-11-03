import SwiftData
import SwiftUI

struct ContentView: View {
    @State private var path: [Route] = []
    @AppStorage("welcomed") private var welcomed = false

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
        .fullScreenCover(isPresented: .constant(!welcomed)) {
            WelcomeView { welcomed = true }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [LevelProgress.self, Creation.self], inMemory: true)
}
