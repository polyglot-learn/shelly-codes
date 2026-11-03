#if DEBUG
    import SwiftData
    import SwiftUI

    /// Debug builds only: `-ui-testing -screenshot <scene>` opens a screen with sample progress,
    /// so scripts/screenshots.sh can capture App Store screenshots.
    enum ScreenshotMode: String {
        case home, level, success, error, freedraw, gallery, shells

        static let current: ScreenshotMode? = {
            let args = ProcessInfo.processInfo.arguments
            guard let index = args.firstIndex(of: "-screenshot"), index + 1 < args.count else { return nil }
            return ScreenshotMode(rawValue: args[index + 1])
        }()

        /// Code to put in the level before running it.
        func code(for level: Level) -> String? {
            switch self {
            case .level, .success: level.solution
            case .error: "for i in range(4)\n    forward(100)\n    left(90)\n"
            default: nil
            }
        }

        var showsSuccess: Bool { self != .level }

        /// Fills the store with sample progress and returns the screen to open.
        func prepare(_ context: ModelContext) -> [Route] {
            UserDefaults.standard.set(true, forKey: "welcomed")
            UserDefaults.standard.set(Shell.ocean.rawValue, forKey: "shell")
            let stars = [3, 3, 3, 2, 3, 3, 3, 3, 2, 3, 3, 2, 3]
            for (level, count) in zip(Curriculum.levels, stars) {
                context.insert(LevelProgress(levelID: level.id, code: level.solution, stars: count, solved: true))
            }
            var creations: [Creation] = []
            for (offset, idea) in Idea.all.enumerated() {
                let creation = Creation(title: idea.title, code: idea.code, date: .now.addingTimeInterval(Double(-offset) * 86_400))
                context.insert(creation)
                creations.append(creation)
            }
            switch self {
            case .home: return []
            case .level, .success: return [.level("3.4")]
            case .error: return [.level("3.1")]
            case .freedraw: return [.freeDraw, .creation(creations[0])]
            case .gallery: return [.freeDraw]
            case .shells: return [.shells]
            }
        }
    }
#endif
