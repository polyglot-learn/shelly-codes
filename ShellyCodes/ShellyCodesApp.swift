import SwiftData
import SwiftUI

@main
struct ShellyCodesApp: App {
    init() {
        if AppEnvironment.isUITesting, let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .fontDesign(.rounded)
                .preferredColorScheme(.light)
        }
        .modelContainer(for: [LevelProgress.self, Creation.self], inMemory: AppEnvironment.isUITesting)
    }
}
