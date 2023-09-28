import TestCases
import XCTest

@MainActor
final class EnumTests: BaseIntegrationTests {
  override func setUp() {
    super.setUp()
    self.app.buttons["Enum"].tap()
    self.clearLogs()
  }

  func testBasics() {
    self.app.buttons["Toggle feature 1 on"].tap()
    XCTAssertEqual(self.app.staticTexts["Feature 1"].exists, true)
    self.assertLogs([
      .unordered(
        """
        Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
        Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
        Store<ComposableArchitecture.PresentationState<Integration.EnumView.Feature.Destination.State>, ComposableArchitecture.PresentationAction<Integration.EnumView.Feature.Destination.Action>>.scope
        StoreOf<Integration.EnumView.Feature>.scope
        Store<ComposableArchitecture.PresentationState<Integration.EnumView.Feature.Destination.State>, ComposableArchitecture.PresentationAction<Integration.EnumView.Feature.Destination.Action>>.scope
        StoreOf<Integration.EnumView.Feature>.scope
        StoreOf<Integration.EnumView.Feature>.scope
        Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.init
        StoreOf<Integration.BasicsView.Feature>.init
        EnumView.body
        StoreOf<Integration.BasicsView.Feature>.init
        BasicsView.body
        """)
    ])
    self.app.buttons["Increment"].tap()
    self.assertLogs([
      .unordered(
        """
        Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
        Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
        Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
        Store<ComposableArchitecture.PresentationState<Integration.EnumView.Feature.Destination.State>, ComposableArchitecture.PresentationAction<Integration.EnumView.Feature.Destination.Action>>.scope
        StoreOf<Integration.EnumView.Feature>.scope
        Store<ComposableArchitecture.PresentationState<Integration.EnumView.Feature.Destination.State>, ComposableArchitecture.PresentationAction<Integration.EnumView.Feature.Destination.Action>>.scope
        StoreOf<Integration.EnumView.Feature>.scope
        StoreOf<Integration.EnumView.Feature>.scope
        StoreOf<Integration.BasicsView.Feature>.scope
        BasicsView.body
        """)
    ])
  }

  func testToggle1On_Toggle1Off() {
    self.app.buttons["Toggle feature 1 on"].tap()
    XCTAssertEqual(self.app.staticTexts["Feature 1"].exists, true)
    self.clearLogs()
    self.app.buttons["Toggle feature 1 off"].tap()
    XCTAssertEqual(self.app.staticTexts["Feature 1"].exists, false)
    self.assertLogs([
      .unordered("""
      Store<ComposableArchitecture.PresentationState<Integration.EnumView.Feature.Destination.State>, ComposableArchitecture.PresentationAction<Integration.EnumView.Feature.Destination.Action>>.scope
      StoreOf<Integration.EnumView.Feature>.scope
      StoreOf<Integration.EnumView.Feature>.scope
      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
      StoreOf<Integration.BasicsView.Feature>.scope
      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
      Store<ComposableArchitecture.PresentationState<Integration.EnumView.Feature.Destination.State>, ComposableArchitecture.PresentationAction<Integration.EnumView.Feature.Destination.Action>>.scope
      StoreOf<Integration.EnumView.Feature>.scope
      EnumView.body
      StoreOf<Integration.BasicsView.Feature>.deinit
      StoreOf<Integration.BasicsView.Feature>.deinit
      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.deinit
      """)
    ])
  }

  func testToggle1On_Toggle2On() {
    self.app.buttons["Toggle feature 1 on"].tap()
    XCTAssertEqual(self.app.staticTexts["Feature 1"].exists, true)
    self.clearLogs()
    self.app.buttons["Toggle feature 2 on"].tap()
    XCTAssertEqual(self.app.staticTexts["Feature 2"].exists, true)
    self.assertLogs([
      .unordered("""
      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
      StoreOf<Integration.BasicsView.Feature>.scope
      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
      Store<ComposableArchitecture.PresentationState<Integration.EnumView.Feature.Destination.State>, ComposableArchitecture.PresentationAction<Integration.EnumView.Feature.Destination.Action>>.scope
      StoreOf<Integration.EnumView.Feature>.scope
      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
      Store<ComposableArchitecture.PresentationState<Integration.EnumView.Feature.Destination.State>, ComposableArchitecture.PresentationAction<Integration.EnumView.Feature.Destination.Action>>.scope
      StoreOf<Integration.EnumView.Feature>.scope
      StoreOf<Integration.EnumView.Feature>.scope
      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.init
      StoreOf<Integration.BasicsView.Feature>.init
      EnumView.body
      StoreOf<Integration.BasicsView.Feature>.deinit
      StoreOf<Integration.BasicsView.Feature>.init
      BasicsView.body
      StoreOf<Integration.BasicsView.Feature>.deinit
      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.deinit
      """)
    ])
  }

  func testDismiss() {
    self.app.buttons["Toggle feature 1 on"].tap()
    XCTAssertEqual(self.app.staticTexts["Feature 1"].exists, true)
    self.clearLogs()
    self.app.buttons["Dismiss"].tap()
    XCTAssertEqual(self.app.staticTexts["Feature 1"].exists, false)
    self.assertLogs([
      .unordered("""
      StoreOf<Integration.EnumView.Feature>.scope
      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
      Store<ComposableArchitecture.PresentationState<Integration.EnumView.Feature.Destination.State>, ComposableArchitecture.PresentationAction<Integration.EnumView.Feature.Destination.Action>>.scope
      StoreOf<Integration.EnumView.Feature>.scope
      Store<ComposableArchitecture.PresentationState<Integration.EnumView.Feature.Destination.State>, ComposableArchitecture.PresentationAction<Integration.EnumView.Feature.Destination.Action>>.scope
      StoreOf<Integration.EnumView.Feature>.scope
      StoreOf<Integration.BasicsView.Feature>.scope
      StoreOf<Integration.EnumView.Feature>.scope
      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
      StoreOf<Integration.BasicsView.Feature>.scope
      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
      Store<ComposableArchitecture.PresentationState<Integration.EnumView.Feature.Destination.State>, ComposableArchitecture.PresentationAction<Integration.EnumView.Feature.Destination.Action>>.scope
      StoreOf<Integration.EnumView.Feature>.scope
      Store<ComposableArchitecture.PresentationState<Integration.EnumView.Feature.Destination.State>, ComposableArchitecture.PresentationAction<Integration.EnumView.Feature.Destination.Action>>.scope
      StoreOf<Integration.EnumView.Feature>.scope
      EnumView.body
      StoreOf<Integration.BasicsView.Feature>.deinit
      StoreOf<Integration.BasicsView.Feature>.deinit
      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.deinit
      """)
    ])
  }
}
