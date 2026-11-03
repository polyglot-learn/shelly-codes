import Testing

@testable import ShellyCodes

/// Every mistake a child is likely to make gets a message that says what to do, on the right line.
struct FriendlyErrorTests {
    @Test(arguments: [
        ("for i in range(4)\n    forward(10)", 1, "Add a colon"),
        ("for i in range(3):\nforward(10)", 2, "pushed in (indented)"),
        ("forward(10)\n    left(90)", 2, "isn't inside a loop"),
        ("if x = 5:\n    pass", 1, "=="),
        ("forward 100", 1, "forward(100)"),
        ("print \"hi\"", 1, "print(\"hello\")"),
        ("fro i in range(4):\n    forward(10)", 1, "Did you mean for?"),
        ("Forward(10)", 1, "capital letters"),
        ("forwrd(10)", 1, "Did you mean forward?"),
        ("print(hello)", 1, "put quotes around it"),
        ("print(\"Score: \" + 5)", 1, "str(...)"),
        ("print(\"hi)", 1, "missing its closing"),
        ("forward(100", 1, "never closed"),
        ("forward(100))", 1, "extra )"),
        ("if True:\n    pass\nelse if False:\n    pass", 3, "elif"),
        ("else:\n    pass", 1, "needs an if"),
        ("forward(\"ten\")", 1, "needs a number"),
        ("forward(\"10\")", 1, "Take away the quotes"),
        ("forward()", 1, "needs 1 value"),
        ("left(90, 90)", 1, "You gave it 2"),
        ("color(\"rd\")", 1, "Did you mean \"red\"?"),
        ("print(1 / 0)", 1, "divide by zero"),
        ("items = [1, 2]\nprint(items[5])", 2, "positions start at 0"),
        ("n = input()", 1, "can't ask questions"),
        ("import pygame", 1, "only knows the turtle"),
        ("count = 0\ndef add():\n    count = count + 1\nadd()", 3, "global count"),
        ("def square(size):\n    pass\nsquare()", 3, "needs 1 value"),
        ("forward = 10\nforward(10)", 2, "variable name by mistake"),
        ("for i in 5:\n    pass", 1, "range(5)"),
        ("break", 1, "inside a for or while loop"),
        ("return 5", 1, "inside a function"),
        ("x = 1\n  y = 2", 2, "pushed in"),
        ("if True:\n        a = 1\n    b = 2", 3, "don't line up"),
        ("3dogs = 1", 1, "can't start with a number"),
        ("print(2 ** 100)", 1, "too big"),
        ("x = ", 1, "ends too early"),
        ("end_fill()", 1, "begin_fill()"),
    ])
    func message(source: String, line: Int, contains text: String) {
        let error = Interpreter.run(source).error
        #expect(error != nil, "expected an error for: \(source)")
        #expect(error?.line == line, "\(error?.message ?? "")")
        #expect(error?.message.contains(text) == true, "got: \(error?.message ?? "nil")")
    }

    @Test func suggestionsAreCloseMatchesOnly() {
        #expect(Suggest.closest(to: "fro", in: ["for", "if"]) == "for")
        #expect(Suggest.closest(to: "lef", in: ["left", "right"]) == "left")
        #expect(Suggest.closest(to: "banana", in: ["left", "right"]) == nil)
        #expect(Suggest.distance("teh", "the") == 1)
    }
}
