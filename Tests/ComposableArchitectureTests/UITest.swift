import XCTest

// This test case demonstrates how one can write UI tests using the swift-dependencies library. We
// do not really recommend writing UI tests in general as they are slow and flakey, but if you must
// then this shows how.
//
// The key to doing this is to set a launch environment variable on your XCUIApplication instance,
// and then check for that value in the entry point of the application. If the environment value
// exists, you can use 'withDependencies' to override dependencies to be used in the UI test.
final class StandupsListUITests: XCTestCase {
  var app: XCUIApplication!

  override func setUpWithError() throws {
    self.continueAfterFailure = false
    self.app = XCUIApplication()
    app.launchEnvironment = [
      "UITesting": "true"
    ]
  }

  func testFoo() {

  }
  
//
//  // This test demonstrates the simple flow of tapping the "Add" button, filling in some fields in
//  // the form, and then adding the standup to the list. It's a very simple test, but it takes
//  // approximately 10 seconds to run, and it depends on a lot of internal implementation details to
//  // get right, such as tapping a button with the literal label "Add".
//  //
//  // This test is also written in the simpler, "unit test" style in StandupsListTests.swift, where
//  // it takes 0.025 seconds (400 times faster) and it even tests more. It further confirms that when
//  // the standup is added to the list its data will be persisted to disk so that it will be
//  // available on next launch.
//  func testAdd() throws {
//    app.launch()
//    app.navigationBars["Daily Standups"].buttons["Add"].tap()
//    let collectionViews = app.collectionViews
//    let titleTextField = collectionViews.textFields["Title"]
//    let nameTextField = collectionViews.textFields["Name"]
//
//    titleTextField.typeText("Engineering")
//
//    nameTextField.tap()
//    nameTextField.typeText("Blob")
//
//    collectionViews.buttons["New attendee"].tap()
//    app.typeText("Blob Jr.")
//
//    app.navigationBars["New standup"].buttons["Add"].tap()
//
//    XCTAssertEqual(collectionViews.staticTexts["Engineering"].exists, true)
//  }
}
