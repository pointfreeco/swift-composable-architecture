import XCTest

final class BindingsAnimationsTests: XCTestCase {

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  func testExample() throws {
    // UI tests must launch the application that they test.
    let app = XCUIApplication()
    app.launch()

    func reset() {
      app.buttons["Reset"].tap()
    }

    var o_oo: String {
      collectionViewsQuery.staticTexts["AnimatedWithObservation_OO"].value as? String ?? ""
    }
    var o_vs: String {
      collectionViewsQuery.staticTexts["AnimatedWithObservation_VS"].value as? String ?? ""
    }
    var b_oo: String {
      collectionViewsQuery.staticTexts["AnimatedFromBinding_OO"].value as? String ?? ""
    }
    var b_vs: String {
      collectionViewsQuery.staticTexts["AnimatedFromBinding_VS"].value as? String ?? ""
    }
    var ob_oo: String {
      collectionViewsQuery.staticTexts["AnimatedFromBindingWithObservation_OO"].value as? String
        ?? ""
    }
    var ob_vs: String {
      collectionViewsQuery.staticTexts["AnimatedFromBindingWithObservation_VS"].value as? String
        ?? ""
    }

    let collectionViewsQuery = app.collectionViews
    collectionViewsQuery.buttons["BindingsAnimationsTestCase"].tap()

    reset()

    XCTAssertEqual(o_oo, "?")
    XCTAssertEqual(o_vs, "?")
    XCTAssertEqual(b_oo, "?")
    XCTAssertEqual(b_vs, "?")
    XCTAssertEqual(ob_oo, "?")
    XCTAssertEqual(ob_vs, "?")

    collectionViewsQuery.switches["AnimatedWithObservation_OO_Toggle"].tap()
    collectionViewsQuery.switches["AnimatedWithObservation_VS_Toggle"].tap()

    Thread.sleep(forTimeInterval: 1)

    XCTAssertEqual(o_oo, "0.7")  // <--
    XCTAssertEqual(o_vs, "0.7")  // <--

    XCTAssertEqual(b_oo, "None")
    XCTAssertEqual(b_vs, "None")
    XCTAssertEqual(ob_oo, "0.7")
    XCTAssertEqual(ob_vs, "0.7")

    reset()

    XCTAssertEqual(o_oo, "?")
    XCTAssertEqual(o_vs, "?")
    XCTAssertEqual(b_oo, "?")
    XCTAssertEqual(b_vs, "?")
    XCTAssertEqual(ob_oo, "?")
    XCTAssertEqual(ob_vs, "?")

    collectionViewsQuery.switches["AnimatedFromBinding_OO_Toggle"].tap()
    collectionViewsQuery.switches["AnimatedFromBinding_VS_Toggle"].tap()

    Thread.sleep(forTimeInterval: 1)

    XCTAssertEqual(o_oo, "0.7")
    XCTAssertEqual(o_vs, "0.7")
    XCTAssertEqual(b_oo, "0.2")  // <--
    XCTAssertEqual(b_vs, "0.2")  // <--
    XCTAssertEqual(ob_oo, "0.7")
    XCTAssertEqual(ob_vs, "0.7")

    reset()

    XCTAssertEqual(o_oo, "?")
    XCTAssertEqual(o_vs, "?")
    XCTAssertEqual(b_oo, "?")
    XCTAssertEqual(b_vs, "?")
    XCTAssertEqual(ob_oo, "?")
    XCTAssertEqual(ob_vs, "?")

    collectionViewsQuery.switches["AnimatedFromBindingWithObservation_OO_Toggle"].tap()
    collectionViewsQuery.switches["AnimatedFromBindingWithObservation_VS_Toggle"].tap()

    Thread.sleep(forTimeInterval: 1)

    XCTAssertEqual(o_oo, "0.7")
    XCTAssertEqual(o_vs, "0.7")
    XCTAssertEqual(b_oo, "0.2")
    XCTAssertEqual(b_vs, "0.2")
    XCTAssertEqual(ob_oo, "0.7")  // <--
    XCTAssertEqual(ob_vs, "0.7")  // <--
  }
}
