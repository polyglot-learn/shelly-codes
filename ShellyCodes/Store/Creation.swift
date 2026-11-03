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

    static let blankCode = """
        # Draw anything you like!
        forward(100)
        """
}

/// Example programs a child can start a new drawing from.
nonisolated struct Idea: Identifiable, Sendable {
    let title: String
    let symbol: String
    let code: String

    var id: String { title }

    static let all = [
        Idea(
            title: "Rainbow Spiral", symbol: "hurricane",
            code: """
                bgcolor("black")
                colors = ["red", "orange", "yellow", "green", "blue", "purple"]
                pensize(2)
                for i in range(120):
                    color(colors[i % 6])
                    forward(i * 1.5)
                    left(59)
                """
        ),
        Idea(
            title: "Starry Night", symbol: "moon.stars.fill",
            code: """
                bgcolor("midnightblue")
                penup()
                for i in range(40):
                    goto(randint(-200, 200), randint(-200, 200))
                    dot(randint(3, 10), "white")
                goto(120, 120)
                dot(80, "lemonchiffon")
                hideturtle()
                """
        ),
        Idea(
            title: "Flower", symbol: "camera.macro",
            code: """
                color("hotpink")
                pensize(2)
                for i in range(12):
                    circle(70)
                    left(30)
                """
        ),
        Idea(
            title: "Little House", symbol: "house.fill",
            code: """
                def square(size):
                    for i in range(4):
                        forward(size)
                        left(90)

                penup()
                goto(-80, -100)
                pendown()
                color("brown", "tan")
                begin_fill()
                square(160)
                end_fill()

                # The roof
                goto(-80, 60)
                color("darkred", "crimson")
                begin_fill()
                goto(0, 140)
                goto(80, 60)
                goto(-80, 60)
                end_fill()

                # The door
                penup()
                goto(-20, -100)
                pendown()
                color("sienna", "chocolate")
                begin_fill()
                for i in range(2):
                    forward(40)
                    left(90)
                    forward(70)
                    left(90)
                end_fill()
                hideturtle()
                """
        ),
    ]
}
