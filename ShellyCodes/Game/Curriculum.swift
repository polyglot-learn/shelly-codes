import Foundation

/// All the levels, in the order a child plays them.
/// Level ids are saved with progress: add new levels, but never renumber shipped ones.
nonisolated enum Curriculum {
    static let chapters: [Chapter] = [moves, talks, loops, pens, smart, spells]

    static let levels: [Level] = chapters.flatMap(\.levels)

    static func level(_ id: String) -> Level? {
        levels.first { $0.id == id }
    }

    static func next(after level: Level) -> Level? {
        guard let index = levels.firstIndex(where: { $0.id == level.id }), index + 1 < levels.count else {
            return nil
        }
        return levels[index + 1]
    }

    static var maxStars: Int { levels.count * 3 }

    private static func at(_ x: Double, _ y: Double, heading: Double = 0) -> TurtleState {
        TurtleState(position: Point(x: x, y: y), heading: heading)
    }

    // MARK: - 1. Shelly Moves

    static let moves = Chapter(
        id: 1, title: "Shelly Moves", subtitle: "forward, left and right",
        symbol: "figure.walk", colorHex: 0x2FBF71,
        levels: [
            Level(
                id: "1.1", title: "Hello, Shelly!",
                story: "Hi! I'm Shelly the turtle, and I follow **Python** code. Tap **Run** and I'll walk to the star!",
                starter: "forward(100)\n",
                solution: "forward(100)",
                chips: ["forward(100)"],
                hints: ["Tap the green Run button!"],
                stars: [Point(x: 0, y: 0)],
                start: at(-100, 0)
            ),
            Level(
                id: "1.2", title: "Far Away",
                story: "That star is far away! Change the number in `forward( )` so I walk all the way there. Each square on the grid is 50 steps.",
                starter: "forward(100)\n",
                solution: "forward(300)",
                chips: ["forward(100)", "forward(300)"],
                hints: [
                    "The number is how many steps Shelly walks.",
                    "Count the grid squares: 6 squares × 50 = 300. Try forward(300).",
                ],
                stars: [Point(x: 150, y: 0)],
                par: 1,
                start: at(-150, 0)
            ),
            Level(
                id: "1.3", title: "Turn Left",
                story: "`left(90)` turns me a quarter of the way round, to my left. Grab both stars!",
                starter: "forward(150)\nleft(90)\n",
                solution: "forward(150)\nleft(90)\nforward(150)",
                chips: ["forward(150)", "left(90)"],
                hints: [
                    "After turning, Shelly needs to walk forward again.",
                    "Add forward(150) on a new line at the end.",
                ],
                stars: [Point(x: 50, y: -100), Point(x: 50, y: 50)],
                par: 3,
                start: at(-100, -100)
            ),
            Level(
                id: "1.4", title: "Stairs",
                story: "Let's draw stairs! `right(90)` turns me to my right. Follow the dotted lines all the way up.",
                starter: "forward(50)\nleft(90)\nforward(50)\nright(90)\n",
                solution: """
                    forward(50)
                    left(90)
                    forward(50)
                    right(90)
                    forward(50)
                    left(90)
                    forward(50)
                    right(90)
                    forward(50)
                    left(90)
                    forward(50)
                    right(90)
                    forward(50)
                    """,
                chips: ["forward(50)", "left(90)", "right(90)"],
                hints: [
                    "The first step is already done. Do the same 4 lines again for the next step.",
                    "There are 3 steps, then one more forward(50) at the top.",
                ],
                checksDrawing: true,
                start: at(-100, -75)
            ),
            Level(
                id: "1.5", title: "Square",
                story: "A square has 4 sides that are all the same, and 4 corners. Draw one along the dotted lines!",
                starter: "forward(100)\nleft(90)\n",
                solution: "forward(100)\nleft(90)\nforward(100)\nleft(90)\nforward(100)\nleft(90)\nforward(100)\nleft(90)",
                chips: ["forward(100)", "left(90)"],
                hints: [
                    "Walk forward, then turn left. Do that 4 times.",
                    "You need forward(100) and left(90) 4 times each.",
                ],
                checksDrawing: true,
                start: at(-50, -50)
            ),
        ]
    )

    // MARK: - 2. Shelly Talks

    static let talks = Chapter(
        id: 2, title: "Shelly Talks", subtitle: "print, numbers and variables",
        symbol: "bubble.left.fill", colorHex: 0x3D8BFD,
        levels: [
            Level(
                id: "2.1", title: "Say Hello",
                story: "`print( )` makes me say something. Words go inside quotes, like `\"this\"`. Make me say **Hello, Shelly!**",
                starter: "print(\"Hi\")\n",
                solution: "print(\"Hello, Shelly!\")",
                chips: ["print(\"Hi\")"],
                hints: [
                    "Change the words between the quotes.",
                    "print(\"Hello, Shelly!\")",
                ],
                checksOutput: true,
                par: 1
            ),
            Level(
                id: "2.2", title: "Super Calculator",
                story: "Python is a super calculator! `*` means times. Make me print what **12 times 7** is, and let Python do the math.",
                starter: "print(2 + 3)\n",
                solution: "print(12 * 7)",
                chips: ["print(2 + 3)", "*"],
                hints: [
                    "Numbers don't need quotes. print(2 + 3) shows 5.",
                    "print(12 * 7)",
                ],
                checksOutput: true,
                concepts: [.arithmetic],
                par: 1
            ),
            Level(
                id: "2.3", title: "Remember It",
                story: "I'm 100 years old. Turtles live a long time! A **variable** is a name that remembers a value. Print how old I'll be in 5 years, using `age + 5`.",
                starter: "age = 100\nprint(age)\n",
                solution: "age = 100\nprint(age + 5)",
                chips: ["age = 100", "print(age)", "+ 5"],
                hints: [
                    "age remembers 100. What is age + 5?",
                    "Change the second line to print(age + 5)",
                ],
                checksOutput: true,
                concepts: [.variable, .arithmetic],
                par: 2
            ),
            Level(
                id: "2.4", title: "Bug Hunt",
                story: "Uh-oh, this code has a **bug**! Run it and read the message. Can you fix it so I say **Shelly is 100 years old**?",
                starter: "print(\"Shelly is \" + 100 + \" years old\")\n",
                solution: "print(\"Shelly is \" + str(100) + \" years old\")",
                chips: ["str(100)"],
                hints: [
                    "Python can't add words and numbers together.",
                    "str(100) turns the number into a word. Put it in place of 100.",
                ],
                checksOutput: true,
                par: 1
            ),
        ]
    )

    // MARK: - 3. Loop-de-Loop

    static let loops = Chapter(
        id: 3, title: "Loop-de-Loop", subtitle: "for loops repeat code",
        symbol: "repeat", colorHex: 0xFF9F1C,
        levels: [
            Level(
                id: "3.1", title: "Loop Square",
                story: "Typing the same thing 4 times is boring. A `for` loop repeats it for me! The lines pushed in with spaces get repeated. Add a turn to finish the square.",
                starter: "for i in range(4):\n    forward(100)\n",
                solution: "for i in range(4):\n    forward(100)\n    left(90)",
                chips: ["for i in range(4):", "forward(100)", "left(90)"],
                hints: [
                    "Put left(90) inside the loop, under forward(100).",
                    "Start the new line with 4 spaces so it lines up with forward(100).",
                ],
                checksDrawing: true,
                concepts: [.forLoop],
                par: 3,
                start: at(-50, -50)
            ),
            Level(
                id: "3.2", title: "Triangle",
                story: "A triangle has 3 sides. To get all the way round I turn 360 degrees, so each corner is 360 ÷ 3 = **120**.",
                starter: "for i in range(3):\n    forward(120)\n",
                solution: "for i in range(3):\n    forward(120)\n    left(120)",
                chips: ["for i in range(3):", "forward(120)", "left(120)"],
                hints: [
                    "Like the square, but turn left(120) each time.",
                    "Add left(120) inside the loop.",
                ],
                checksDrawing: true,
                concepts: [.forLoop],
                par: 3,
                start: at(-60, -50)
            ),
            Level(
                id: "3.3", title: "Count with Me",
                story: "Run this. I count from 0 to 4, because Python starts counting at **0**! Change it so I count from **1 to 5**.",
                starter: "for i in range(5):\n    print(i)\n",
                solution: "for i in range(1, 6):\n    print(i)",
                chips: ["for i in range(1, 6):", "print(i)"],
                hints: [
                    "range(1, 6) starts at 1 and stops just before 6.",
                    "Change range(5) to range(1, 6).",
                ],
                checksOutput: true,
                concepts: [.forLoop],
                par: 2
            ),
            Level(
                id: "3.4", title: "Star Power",
                story: "Let's draw a star! It has 5 points. At each point I turn `right(144)`.",
                starter: "for i in range(5):\n    forward(150)\n",
                solution: "for i in range(5):\n    forward(150)\n    right(144)",
                chips: ["for i in range(5):", "forward(150)", "right(144)"],
                hints: [
                    "Add a turn inside the loop.",
                    "Add right(144) under forward(150), lined up with it.",
                ],
                checksDrawing: true,
                concepts: [.forLoop],
                par: 3,
                start: at(-75, 15)
            ),
            Level(
                id: "3.5", title: "Beehive",
                story: "Bees build their homes from **hexagons**: 6 sides of 70 steps. Each corner turns 360 ÷ 6. Write the whole loop yourself!",
                starter: "# Draw a hexagon with a for loop\n",
                solution: "for i in range(6):\n    forward(70)\n    left(60)",
                chips: ["for i in range(6):", "forward(70)", "left(60)"],
                hints: [
                    "360 ÷ 6 = 60, so turn left(60) at each corner.",
                    "for i in range(6):\n    forward(70)\n    left(60)",
                ],
                checksDrawing: true,
                concepts: [.forLoop],
                par: 3,
                start: at(-35, -60)
            ),
        ]
    )

    // MARK: - 4. Colors & Pens

    static let pens = Chapter(
        id: 4, title: "Colors & Pens", subtitle: "color, penup, circles and fills",
        symbol: "paintpalette.fill", colorHex: 0xE5468C,
        levels: [
            Level(
                id: "4.1", title: "Red Square",
                story: "My pen can be any color! Put `color(\"red\")` on the first line to draw a red square.",
                starter: "for i in range(4):\n    forward(100)\n    left(90)\n",
                solution: "color(\"red\")\nfor i in range(4):\n    forward(100)\n    left(90)",
                chips: ["color(\"red\")", "color(\"blue\")", "color(\"purple\")"],
                hints: [
                    "Add color(\"red\") as a new first line, before for.",
                    "Don't push it in with spaces: it goes before the loop, not inside it.",
                ],
                checksDrawing: true,
                calls: ["color"],
                par: 4,
                start: at(-50, -50)
            ),
            Level(
                id: "4.2", title: "Jump!",
                story: "`penup()` lifts my pen, so I can walk without drawing. `pendown()` puts it back. Draw the two lines with a gap in the middle.",
                starter: "forward(100)\n",
                solution: "forward(100)\npenup()\nforward(100)\npendown()\nforward(100)",
                chips: ["forward(100)", "penup()", "pendown()"],
                hints: [
                    "Draw, lift the pen, walk, put the pen down, draw again.",
                    "forward(100), penup(), forward(100), pendown(), forward(100)",
                ],
                checksDrawing: true,
                calls: ["penup"],
                par: 5,
                start: at(-150, 0)
            ),
            Level(
                id: "4.3", title: "Dashed Line",
                story: "Use a loop to draw a dashed line: draw 25 steps, then jump 25 steps, 6 times.",
                starter: "for i in range(6):\n    forward(25)\n",
                solution: "for i in range(6):\n    forward(25)\n    penup()\n    forward(25)\n    pendown()",
                chips: ["for i in range(6):", "forward(25)", "penup()", "pendown()"],
                hints: [
                    "Inside the loop: draw, lift the pen, walk, put the pen down.",
                    "Add penup(), forward(25) and pendown() inside the loop.",
                ],
                checksDrawing: true,
                concepts: [.forLoop],
                par: 5,
                start: at(-150, 0)
            ),
            Level(
                id: "4.4", title: "Round and Round",
                story: "`circle(50)` walks me round in a circle. The number is the **radius**: how far the middle is from the edge. Draw the big dotted circle!",
                starter: "circle(50)\n",
                solution: "circle(100)",
                chips: ["circle(50)", "circle(100)"],
                hints: [
                    "The circle needs to be bigger.",
                    "The middle of the circle is 100 steps above Shelly. Try circle(100).",
                ],
                checksDrawing: true,
                calls: ["circle"],
                par: 1,
                start: at(0, -100)
            ),
            Level(
                id: "4.5", title: "Sunny Day",
                story: "Let's paint a sun! `begin_fill()` and `end_fill()` color in the shape you draw between them.",
                starter: "color(\"orange\", \"yellow\")\ncircle(80)\n",
                solution: "color(\"orange\", \"yellow\")\nbegin_fill()\ncircle(80)\nend_fill()",
                chips: ["begin_fill()", "end_fill()", "circle(80)"],
                hints: [
                    "begin_fill() goes before the circle, end_fill() after it.",
                    "Put begin_fill() on the line before circle(80) and end_fill() on the line after.",
                ],
                checksDrawing: true,
                calls: ["begin_fill", "end_fill"],
                par: 4,
                start: at(0, -80)
            ),
        ]
    )

    // MARK: - 5. Smart Shelly

    static let smart = Chapter(
        id: 5, title: "Smart Shelly", subtitle: "variables, lists, if and while",
        symbol: "lightbulb.fill", colorHex: 0x8E5CF7,
        levels: [
            Level(
                id: "5.1", title: "Growing Spiral",
                story: "Variables can change! If `size` gets bigger every time round the loop, I draw a spiral. Add `size = size + 10` inside the loop.",
                starter: "size = 10\nfor i in range(16):\n    forward(size)\n    left(90)\n",
                solution: "size = 10\nfor i in range(16):\n    forward(size)\n    left(90)\n    size = size + 10",
                chips: ["size = size + 10", "forward(size)", "left(90)"],
                hints: [
                    "The new line goes inside the loop, so it needs 4 spaces in front.",
                    "Add    size = size + 10    as the last line, lined up with left(90).",
                ],
                checksDrawing: true,
                concepts: [.forLoop, .variable],
                par: 5,
                start: at(-5, -5)
            ),
            Level(
                id: "5.2", title: "Rainbow Road",
                story: "A **list** holds many things inside `[ ]`. A for loop can go through a list one thing at a time. Add green, blue and purple to finish the rainbow!",
                starter: "colors = [\"red\", \"orange\", \"yellow\"]\nfor c in colors:\n    color(c)\n    forward(50)\n",
                solution: "colors = [\"red\", \"orange\", \"yellow\", \"green\", \"blue\", \"purple\"]\nfor c in colors:\n    color(c)\n    forward(50)",
                chips: ["\"green\"", "\"blue\"", "\"purple\"", ","],
                hints: [
                    "Add more colors inside the [ ], with commas between them.",
                    "colors = [\"red\", \"orange\", \"yellow\", \"green\", \"blue\", \"purple\"]",
                ],
                checksDrawing: true,
                concepts: [.forLoop],
                calls: ["color"],
                par: 4,
                start: at(-150, 0)
            ),
            Level(
                id: "5.3", title: "Even or Odd",
                story: "`if` lets me decide! `n % 2` is what's left over after dividing by 2. If it's 0, the number is even. Add an `else:` so I also say which numbers are odd.",
                starter: "for n in range(1, 7):\n    if n % 2 == 0:\n        print(n, \"is even\")\n",
                solution:
                    "for n in range(1, 7):\n    if n % 2 == 0:\n        print(n, \"is even\")\n    else:\n        print(n, \"is odd\")",
                chips: ["else:", "print(n, \"is odd\")"],
                hints: [
                    "else: lines up with if, and the line under it is pushed in further.",
                    "Add    else:    (4 spaces) and then    print(n, \"is odd\")    (8 spaces).",
                ],
                checksOutput: true,
                concepts: [.ifStatement],
                par: 5
            ),
            Level(
                id: "5.4", title: "Countdown",
                story: "A `while` loop keeps going as long as something is True. This one never stops: run it and see! Make `n` smaller each time, then print **Blast off!** at the end.",
                starter: "n = 5\nwhile n > 0:\n    print(n)\n",
                solution: "n = 5\nwhile n > 0:\n    print(n)\n    n = n - 1\nprint(\"Blast off!\")",
                chips: ["n = n - 1", "print(\"Blast off!\")"],
                hints: [
                    "Inside the loop, add n = n - 1 so n gets smaller.",
                    "Put print(\"Blast off!\") at the very end, with no spaces in front.",
                ],
                checksOutput: true,
                concepts: [.whileLoop],
                par: 5
            ),
        ]
    )

    // MARK: - 6. Shelly's Spells

    static let spells = Chapter(
        id: 6, title: "Shelly's Spells", subtitle: "make your own commands with def",
        symbol: "wand.and.stars", colorHex: 0x14B8C4,
        levels: [
            Level(
                id: "6.1", title: "Square Spell",
                story: "`def` teaches me a new spell, called a **function**. Here I learned `square()`. Use it again to draw a second square, with a gap between them.",
                starter:
                    "def square():\n    for i in range(4):\n        forward(60)\n        left(90)\n\nsquare()\npenup()\nforward(100)\npendown()\n",
                solution:
                    "def square():\n    for i in range(4):\n        forward(60)\n        left(90)\n\nsquare()\npenup()\nforward(100)\npendown()\nsquare()",
                chips: ["square()", "penup()", "pendown()", "forward(100)"],
                hints: [
                    "To use a spell, write its name with ( ) after it.",
                    "Add square() on the last line.",
                ],
                checksDrawing: true,
                concepts: [.function],
                start: at(-80, -30)
            ),
            Level(
                id: "6.2", title: "Size Spell",
                story: "Spells can take a value! In `def square(size):`, `size` is whatever number you give it. Draw three squares: **40**, **80** and **120**.",
                starter: "def square(size):\n    for i in range(4):\n        forward(size)\n        left(90)\n\nsquare(40)\n",
                solution:
                    "def square(size):\n    for i in range(4):\n        forward(size)\n        left(90)\n\nsquare(40)\nsquare(80)\nsquare(120)",
                chips: ["square(40)", "square(80)", "square(120)"],
                hints: [
                    "Call the spell again with a different number.",
                    "Add square(80) and square(120) at the end.",
                ],
                checksDrawing: true,
                concepts: [.functionWithParameters],
                start: at(-60, -60)
            ),
            Level(
                id: "6.3", title: "Flower Power",
                story: "Let's grow a flower! The `petal()` spell draws one petal. Use a loop to draw **6 petals**, turning `left(60)` after each one.",
                starter:
                    "def petal():\n    circle(80, 60)\n    left(120)\n    circle(80, 60)\n    left(120)\n\ncolor(\"hotpink\")\npetal()\n",
                solution:
                    "def petal():\n    circle(80, 60)\n    left(120)\n    circle(80, 60)\n    left(120)\n\ncolor(\"hotpink\")\nfor i in range(6):\n    petal()\n    left(60)",
                chips: ["for i in range(6):", "petal()", "left(60)"],
                hints: [
                    "Put petal() inside a for loop that runs 6 times.",
                    "for i in range(6):\n    petal()\n    left(60)",
                ],
                checksDrawing: true,
                concepts: [.function, .forLoop],
                start: at(0, 0)
            ),
            Level(
                id: "6.4", title: "Spin Art",
                story: "The grand finale! `shape(size)` draws a hexagon. Draw it **12 times**, turning `left(30)` after each one, and watch the magic.",
                starter:
                    "def shape(size):\n    for i in range(6):\n        forward(size)\n        left(60)\n\ncolor(\"purple\")\nshape(70)\n",
                solution:
                    "def shape(size):\n    for i in range(6):\n        forward(size)\n        left(60)\n\ncolor(\"purple\")\nfor i in range(12):\n    shape(70)\n    left(30)",
                chips: ["for i in range(12):", "shape(70)", "left(30)"],
                hints: [
                    "Put shape(70) inside a loop that runs 12 times.",
                    "for i in range(12):\n    shape(70)\n    left(30)",
                ],
                checksDrawing: true,
                concepts: [.function, .forLoop],
                start: at(0, 0)
            ),
        ]
    )
}
