import SwiftUI

/// Shown once, the first time the app opens.
struct WelcomeView: View {
    let start: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bob = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            ShellyView(shell: .meadow, heading: 90)
                .frame(width: 220, height: 220)
                .offset(y: bob ? -10 : 10)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: bob)
            Text("Hi, I'm Shelly!")
                .font(.system(size: 56, weight: .heavy, design: .rounded))
            Text(
                "I'm a turtle who follows **Python** code. Python is a real programming language that grown-up programmers use every day.\n\nWrite code, tap **Run**, and watch me draw. Let's learn it together!"
            )
            .font(.system(size: 24, weight: .medium, design: .rounded))
            .multilineTextAlignment(.center)
            .frame(maxWidth: 620)
            Button(action: start) {
                Label("Let's Go!", systemImage: "arrow.right")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .frame(minWidth: 260, minHeight: 66)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: 0x2FBF71))
            .buttonBorderShape(.capsule)
            .accessibilityIdentifier("welcomeStartButton")
            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.paper)
        .onAppear { bob = !reduceMotion }
    }
}

#Preview {
    WelcomeView {}
}
