import Foundation
import Testing

@testable import ShellyCodes

/// Runs a program and returns what it printed, failing the test if it errors.
private func output(_ source: String, sourceLocation: SourceLocation = #_sourceLocation) -> String {
    let result = Interpreter.run(source, seed: 1)
    #expect(result.error == nil, "\(result.error?.message ?? "")", sourceLocation: sourceLocation)
    return result.output
}

struct InterpreterTests {
    @Test(arguments: [
        ("print(7 // 2, -7 // 2, 7 % 3, -7 % 3, 7 % -3)", "3 -4 1 2 -2\n"),
        ("print(1 / 2, 6 / 3, 2 ** 10, 2 ** -1)", "0.5 2.0 1024 0.5\n"),
        ("print(0.1 + 0.2, 3.0, 1e16, -0.5)", "0.30000000000000004 3.0 1e+16 -0.5\n"),
        ("print(round(2.5), round(3.5), round(3.14159, 2), abs(-4), int(3.9), float(2))", "2 4 3.14 4 3 2.0\n"),
        ("print(True + 1, not 0, 1 < 2 < 3, 3 > 2 > 2)", "2 True True False\n"),
        ("print('ab' * 3, 'b' in 'abc', 4 in range(0, 10, 2), 3 not in [1, 2])", "ababab True True True\n"),
        ("print([1, 'two', 3.0, None, True])", "[1, 'two', 3.0, None, True]\n"),
        ("print('a', 'b', sep='-', end='!')\nprint()", "a-b!\n"),
        ("print(len('hello'), len([1, 2]), len(range(1, 10, 3)))", "5 2 3\n"),
        ("print(str(5) + '!', int(' 42 '), float('2.5'))", "5! 42 2.5\n"),
        ("print(min(3, 1, 2), max([4, 9, 2]), sum(range(5)), sorted([3, 1, 2]))", "1 9 10 [1, 2, 3]\n"),
        ("print('Shelly'.upper(), 'HI'.lower(), 'banana'.count('a'), 'cat'.replace('c', 'b'))", "SHELLY hi 3 bat\n"),
        ("x = 0 or 'fallback'\ny = 5 and 6\nprint(x, y)", "fallback 6\n"),
    ])
    func expressions(source: String, expected: String) {
        #expect(output(source) == expected)
    }

    @Test func listsAndIndexing() {
        let source = """
            items = [3, 1, 2]
            items.append(9)
            items[0] = 7
            last = items.pop()
            items.insert(0, 5)
            items.remove(1)
            print(items, last, items[-1], items.index(7), list(range(3)))
            """
        #expect(output(source) == "[5, 7, 2] 9 2 1 [0, 1, 2]\n")
    }

    @Test func loopsBreakAndContinue() {
        let source = """
            for i in range(10):
                if i == 2:
                    continue
                if i == 5:
                    break
                print(i, end=' ')
            n = 3
            while n > 0:
                n -= 1
            print(n)
            for letter in 'hi':
                print(letter)
            for x in range(5, 0, -2):
                print(x)
            """
        #expect(output(source) == "0 1 3 4 0\nh\ni\n5\n3\n1\n")
    }

    @Test func functionsReturnAndRecursion() {
        let source = """
            def add(a, b):
                return a + b

            def factorial(n):
                if n <= 1:
                    return 1
                return n * factorial(n - 1)

            def greet(name):
                print('hi', name)

            print(add(2, 3), factorial(5), add(b=1, a=2))
            greet('Sam')
            """
        #expect(output(source) == "5 120 3\nhi Sam\n")
    }

    @Test func globalAndLocalScope() {
        let source = """
            count = 0
            def bump():
                global count
                count = count + 1
            def local():
                count = 100
                return count
            bump()
            bump()
            print(count, local(), count)
            """
        #expect(output(source) == "2 100 2\n")
    }

    @Test func oneLineBlocksAndComments() {
        let source = """
            # a comment
            for i in range(2): print(i)  # trailing comment
            if True: print('yes')
            """
        #expect(output(source) == "0\n1\nyes\n")
    }

    @Test func importsAndTurtleObjectStyle() {
        let source = """
            import turtle
            import random as r
            from math import sqrt, pi
            from random import *
            t = turtle.Turtle()
            t.forward(10)
            screen = turtle.Screen()
            screen.bgcolor('black')
            print(sqrt(16), round(pi, 2), r.randint(3, 3), randint(4, 4))
            turtle.done()
            """
        #expect(output(source) == "4.0 3.14 3 4\n")
    }

    @Test func seededRandomIsRepeatable() {
        let source = "print(randint(1, 1000), choice(['a', 'b', 'c']), random() < 1)"
        #expect(Interpreter.run(source, seed: 42).output == Interpreter.run(source, seed: 42).output)
    }

    @Test func smartQuotesAndTabsFromTheKeyboardStillWork() {
        #expect(output("print(\u{201C}hi\u{201D})\nfor i in range(1):\n\tprint(\u{2018}ok\u{2019})") == "hi\nok\n")
    }

    @Test func runawayLoopsStop() {
        let spin = Interpreter.run("while True:\n    pass")
        #expect(spin.error?.message.contains("dizzy") == true)
        let walk = Interpreter.run("while True:\n    forward(1)")
        #expect(walk.error?.message.contains("tired") == true)
        let deep = Interpreter.run("def f():\n    f()\nf()")
        #expect(deep.error?.message.contains("too many times") == true)
        let chatter = Interpreter.run("while True:\n    print('hello')")
        #expect(chatter.error?.message.contains("loop that never stops") == true)
    }

    @Test func deepNestingIsAFriendlyError() {
        let brackets = String(repeating: "(", count: 500) + "1" + String(repeating: ")", count: 500)
        #expect(Interpreter.run("print(\(brackets))").error?.message.contains("too many things inside each other") == true)
        #expect(Interpreter.run("print(" + String(repeating: "-", count: 500) + "1)").error != nil)
        var nestedLoops = ""
        for level in 0..<150 { nestedLoops += String(repeating: " ", count: level * 4) + "if True:\n" }
        nestedLoops += String(repeating: " ", count: 150 * 4) + "pass\n"
        #expect(Interpreter.run(nestedLoops).error != nil)
    }

    @Test func eventsBeforeAnErrorAreKept() {
        let result = Interpreter.run("forward(50)\nforward(oops)")
        #expect(result.error?.line == 2)
        #expect(Drawing(result.events).segments.count == 1)
    }
}
