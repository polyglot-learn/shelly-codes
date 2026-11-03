import Foundation

/// Shell colors for Shelly, unlocked by collecting stars.
nonisolated enum Shell: String, CaseIterable, Identifiable, Sendable {
    case meadow, ocean, berry, sunset, bubblegum, golden

    var id: String { rawValue }

    var name: String {
        switch self {
        case .meadow: "Meadow"
        case .ocean: "Ocean"
        case .berry: "Berry"
        case .sunset: "Sunset"
        case .bubblegum: "Bubblegum"
        case .golden: "Golden"
        }
    }

    var starsNeeded: Int {
        switch self {
        case .meadow: 0
        case .ocean: 10
        case .berry: 25
        case .sunset: 40
        case .bubblegum: 60
        case .golden: 75
        }
    }

    /// Main shell color and the color of its pattern.
    var colors: (shell: UInt32, pattern: UInt32) {
        switch self {
        case .meadow: (0x2FBF71, 0x1E8C50)
        case .ocean: (0x3D8BFD, 0x1F5FC4)
        case .berry: (0x8E5CF7, 0x6236C9)
        case .sunset: (0xFF8A3D, 0xD9572A)
        case .bubblegum: (0xFF6FB5, 0xD9438C)
        case .golden: (0xF5C518, 0xC99A06)
        }
    }

    func isUnlocked(stars: Int) -> Bool {
        stars >= starsNeeded
    }

    /// The first shell still locked, to show what the child is working towards.
    static func nextLocked(stars: Int) -> Shell? {
        allCases.first { !$0.isUnlocked(stars: stars) }
    }
}

nonisolated enum PlaybackSpeed: String, CaseIterable, Identifiable, Sendable {
    case slow, normal, fast

    var id: String { rawValue }

    var label: String {
        switch self {
        case .slow: "Slow"
        case .normal: "Normal"
        case .fast: "Fast"
        }
    }

    var symbol: String {
        switch self {
        case .slow: "tortoise.fill"
        case .normal: "figure.walk"
        case .fast: "hare.fill"
        }
    }

    /// Steps per second when walking.
    var stepsPerSecond: Double {
        switch self {
        case .slow: 120
        case .normal: 300
        case .fast: 1000
        }
    }

    /// Degrees per second when turning.
    var degreesPerSecond: Double {
        switch self {
        case .slow: 180
        case .normal: 480
        case .fast: 1600
        }
    }

    /// The longest a replay may take; longer programs are sped up to fit.
    var maxSeconds: Double {
        switch self {
        case .slow: 30
        case .normal: 15
        case .fast: 6
        }
    }
}
