import Foundation

enum AppEnvironment {
    /// UI tests launch with -ui-testing: in-memory storage, fresh settings and instant replays.
    static let isUITesting = ProcessInfo.processInfo.arguments.contains("-ui-testing")
}
