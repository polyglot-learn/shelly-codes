import XCTest

final class ShellyCodesUITests: XCTestCase {
    func testLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.navigationBars["Shelly Codes"].waitForExistence(timeout: 5))
    }
}
