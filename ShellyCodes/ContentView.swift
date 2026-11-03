import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Welcome to Shelly Codes", systemImage: "sparkles")
                .navigationTitle("Shelly Codes")
        }
    }
}

#Preview {
    ContentView()
}
