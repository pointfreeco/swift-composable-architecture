import XCTest

@MainActor
final class EscapedWithViewStoreTests: XCTestCase {

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  func testExample() async throws {
    let app = XCUIApplication()
    app.launch()

    app.collectionViews.buttons["EscapedWithViewStoreTestCase"].tap()

    XCTAssertEqual(app.staticTexts["Label"].value as? String, "10")
    XCTAssertEqual(app.staticTexts["EscapedLabel"].value as? String, "10")

    app.buttons["Button"].tap()

    XCTAssertEqual(app.staticTexts["Label"].value as? String, "11")
    XCTAssertEqual(app.staticTexts["EscapedLabel"].value as? String, "11")

    let stepper = app.steppers["Stepper"]

    stepper.buttons["Increment"].tap()
    stepper.buttons["Increment"].tap()
    stepper.buttons["Increment"].tap()
    stepper.buttons["Increment"].tap()

    XCTAssertEqual(app.staticTexts["Label"].value as? String, "15")
    XCTAssertEqual(app.staticTexts["EscapedLabel"].value as? String, "15")

    stepper.buttons["Decrement"].tap()
    stepper.buttons["Decrement"].tap()
    stepper.buttons["Decrement"].tap()

    XCTAssertEqual(app.staticTexts["Label"].value as? String, "12")
    XCTAssertEqual(app.staticTexts["EscapedLabel"].value as? String, "12")
  }
}
