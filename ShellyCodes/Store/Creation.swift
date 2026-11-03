import Foundation
import SwiftData

/// A free-draw program the child made and saved.
@Model
final class Creation {
    var title: String
    var code: String
    var createdAt: Date
    var updatedAt: Date

    init(title: String, code: String, date: Date = .now) {
        self.title = title
        self.code = code
        self.createdAt = date
        self.updatedAt = date
    }

    static let starterCode = """
        # Draw anything you like!
        color("purple")
        for i in range(36):
            circle(80)
            left(10)
        """
}
