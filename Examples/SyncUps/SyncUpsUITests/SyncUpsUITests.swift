import XCTest

final class SyncUpsUITests: XCTestCase {
  @MainActor
  var app: XCUIApplication!

  @MainActor
  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchEnvironment = [
      "UITesting": "true"
    ]
  }

  // This test demonstrates the simple flow of tapping the "Add" button, filling in some fields in
  // the form, and then adding the sync-up to the list. It's a very simple test, but it takes
  // approximately 10 seconds to run, and it depends on a lot of internal implementation details to
  // get right, such as tapping a button with the literal label "Add".
  //
  // This test is also written in the simpler, "unit test" style in SyncUpsListTests.swift, where
  // it takes 0.025 seconds (400 times faster) and it even tests more. It further confirms that when
  // the sync-up is added to the list its data will be persisted to disk so that it will be
  // available on next launch.
  @MainActor
  func testAdd() throws {
    app.launch()
    app.navigationBars["Daily Sync-ups"].buttons["Add"].tap()

    let collectionViews = app.collectionViews
    let titleTextField = collectionViews.textFields["Title"]
    let nameTextField = collectionViews.textFields["Name"]

    titleTextField.typeText("Engineering")

    nameTextField.tap()
    nameTextField.typeText("Blob")

    collectionViews.buttons["New attendee"].tap()
    app.typeText("Blob Jr.")

    app.navigationBars["New sync-up"].buttons["Add"].tap()

    XCTAssertEqual(collectionViews.staticTexts["Engineering"].exists, true)
  }
}
