import Foundation
import Testing

@testable import ShellyCodes

struct ProgressTests {
    @Test func levelsUnlockOneAtATime() {
        #expect(Unlocks.isUnlocked("1.1", solved: [], unlockAll: false))
        #expect(!Unlocks.isUnlocked("1.2", solved: [], unlockAll: false))
        #expect(Unlocks.isUnlocked("1.2", solved: ["1.1"], unlockAll: false))
        #expect(Unlocks.isUnlocked("2.1", solved: ["1.5"], unlockAll: false))
        #expect(Unlocks.isUnlocked("6.4", solved: [], unlockAll: true))
    }

    @Test func nextUpIsTheFirstOpenUnsolvedLevel() {
        #expect(Unlocks.nextUp(solved: [], unlockAll: false)?.id == "1.1")
        #expect(Unlocks.nextUp(solved: ["1.1", "1.2"], unlockAll: false)?.id == "1.3")
        let all = Set(Curriculum.levels.map(\.id))
        #expect(Unlocks.nextUp(solved: all, unlockAll: false) == nil)
    }

    @Test func shellsUnlockWithStars() {
        #expect(Shell.meadow.isUnlocked(stars: 0))
        #expect(!Shell.ocean.isUnlocked(stars: 9))
        #expect(Shell.ocean.isUnlocked(stars: 10))
        #expect(Shell.nextLocked(stars: 12) == .berry)
        #expect(Shell.nextLocked(stars: Curriculum.maxStars) == nil)
        #expect(Shell.allCases.allSatisfy { $0.starsNeeded <= Curriculum.maxStars })
    }
}
