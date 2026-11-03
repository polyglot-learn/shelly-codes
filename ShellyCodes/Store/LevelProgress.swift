import Foundation
import SwiftData

/// A child's progress on one level: their latest code and best star rating.
@Model
final class LevelProgress {
    @Attribute(.unique) var levelID: String
    var code: String
    var stars: Int
    var solved: Bool

    init(levelID: String, code: String, stars: Int = 0, solved: Bool = false) {
        self.levelID = levelID
        self.code = code
        self.stars = stars
        self.solved = solved
    }
}

/// Which levels are open. The first level is always open; each later one opens when the one
/// before it is solved, or all of them when a grown-up turns on "Unlock all levels".
nonisolated enum Unlocks {
    static func isUnlocked(_ levelID: String, solved: Set<String>, unlockAll: Bool) -> Bool {
        if unlockAll { return true }
        guard let index = Curriculum.levels.firstIndex(where: { $0.id == levelID }) else { return false }
        return index == 0 || solved.contains(Curriculum.levels[index - 1].id)
    }

    /// The level to suggest on the home screen: the first unsolved open one.
    static func nextUp(solved: Set<String>, unlockAll: Bool) -> Level? {
        Curriculum.levels.first { !solved.contains($0.id) && isUnlocked($0.id, solved: solved, unlockAll: unlockAll) }
    }
}
