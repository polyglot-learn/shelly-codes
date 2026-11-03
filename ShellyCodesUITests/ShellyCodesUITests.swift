import XCTest

final class ShellyCodesUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Launches with fresh, in-memory data and gets past the welcome screen.
    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        let start = app.buttons["welcomeStartButton"]
        XCTAssertTrue(start.waitForExistence(timeout: 10), "line 15")
        start.tap()
        return app
    }

    @MainActor
    func testSolveFirstLevelsWithRunHintsAndChips() {
        let app = launch()
        app.buttons["continueButton"].tap()
        XCTAssertTrue(app.navigationBars["1.1  Hello, Shelly!"].waitForExistence(timeout: 5))

        app.buttons["runButton"].tap()
        XCTAssertTrue(app.staticTexts["successTitle"].waitForExistence(timeout: 5), "line 27")
        app.buttons["nextLevelButton"].tap()
        XCTAssertTrue(app.navigationBars["1.2  Far Away"].waitForExistence(timeout: 5), "line 29")

        // The starter code stops short of the star.
        app.buttons["runButton"].tap()
        let bubble = app.descendants(matching: .any)["bubbleMessage"]
        XCTAssertTrue(bubble.waitForExistence(timeout: 5), "line 34")
        XCTAssertTrue(bubble.label.contains("So close"), bubble.label)

        app.buttons["hintButton"].tap()
        XCTAssertTrue(bubble.label.contains("how many steps"), bubble.label)

        // A chip adds a whole command on a new line.
        app.buttons["chip-forward(300)"].tap()
        app.buttons["runButton"].tap()
        XCTAssertTrue(app.staticTexts["successTitle"].waitForExistence(timeout: 5), "line 43")
        app.buttons["playAgainButton"].tap()

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["level-1.3"].waitForExistence(timeout: 5), "line 47")
        XCTAssertTrue(app.buttons["level-1.3"].isEnabled, "line 48")
        XCTAssertFalse(app.buttons["level-1.4"].isEnabled, "line 49")
    }

    @MainActor
    func testMistakesGetFriendlyHelp() {
        let app = launch()
        app.buttons["continueButton"].tap()
        let editor = app.textViews["codeEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5), "line 57")
        editor.tap()
        // XCUITest can't see focus inside this UITextView, so give it a moment and type at the app level.
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "focus")], timeout: 1)
        app.typeText("\nforwrd(10)")
        app.buttons["runButton"].tap()
        let bubble = app.descendants(matching: .any)["bubbleMessage"]
        XCTAssertTrue(bubble.waitForExistence(timeout: 5), "line 63")
        XCTAssertTrue(bubble.label.contains("Did you mean forward?"), bubble.label)

        app.buttons["startOverButton"].tap()
        let confirm = app.buttons.matching(
            NSPredicate(format: "label == 'Start Over' AND identifier != 'startOverButton'")
        ).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "start over confirmation")
        confirm.tap()
        app.buttons["runButton"].tap()
        XCTAssertTrue(app.staticTexts["successTitle"].waitForExistence(timeout: 5), "line 69")
    }

    @MainActor
    func testGrownUpsAreaIsBehindAGate() {
        let app = launch()
        app.buttons["grownUpsButton"].tap()
        let answer = app.textFields["gateAnswer"]
        XCTAssertTrue(answer.waitForExistence(timeout: 5), "line 77")
        answer.typeText("55")
        app.buttons["gateContinue"].tap()
        XCTAssertTrue(app.staticTexts["That's not right. Please ask a grown-up."].waitForExistence(timeout: 5), "line 80")

        // In UI tests the question is always 7 × 8.
        answer.typeText("56")
        app.buttons["gateContinue"].tap()
        let unlockAll = app.switches["unlockAllToggle"]
        XCTAssertTrue(unlockAll.waitForExistence(timeout: 5), "line 86")
        unlockAll.switches.firstMatch.tap()
        app.buttons["doneButton"].tap()

        XCTAssertTrue(app.buttons["level-6.4"].waitForExistence(timeout: 5), "line 90")
        XCTAssertTrue(app.buttons["level-6.4"].isEnabled, "line 91")
    }

    @MainActor
    func testFreeDrawSavesADrawing() {
        let app = launch()
        app.buttons["freeDrawButton"].tap()
        app.buttons["newCreationButton"].tap()
        XCTAssertTrue(app.buttons["runButton"].waitForExistence(timeout: 5), "line 99")
        app.buttons["chip-circle(50)"].tap()
        app.buttons["runButton"].tap()
        XCTAssertTrue(app.otherElements["canvas"].waitForExistence(timeout: 5), "line 102")
        XCTAssertTrue(app.otherElements["canvas"].value as? String == "Shelly drew 21 lines.", "line 103")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["My drawings"].waitForExistence(timeout: 5), "line 106")
        XCTAssertTrue(app.staticTexts["Drawing 1"].exists, "line 107")
    }
}
