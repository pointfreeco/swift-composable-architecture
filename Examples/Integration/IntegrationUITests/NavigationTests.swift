import TestCases
import XCTest

@MainActor
final class NavigationTests: BaseIntegrationTests {
  override func setUp() {
    super.setUp()
    self.app.buttons["Navigation"].tap()
    self.clearLogs()
  }

  func testBasics() {
    self.app.buttons["Push feature"].tap()
    self.assertLogs("""
    Store<ComposableArchitecture.StackState<Integration.BasicsView.Feature.State>, ComposableArchitecture.StackAction<Integration.BasicsView.Feature.State, Integration.BasicsView.Feature.Action>>.init
    StoreOf<Integration.BasicsView.Feature>.init
    StoreOf<Integration.BasicsView.Feature>.init
    BasicsView.body
    """)
    self.app.buttons["Increment"].tap()
    self.assertLogs("""
    Store<ComposableArchitecture.StackState<Integration.BasicsView.Feature.State>, ComposableArchitecture.StackAction<Integration.BasicsView.Feature.State, Integration.BasicsView.Feature.Action>>.scope
    StoreOf<Integration.NavigationTestCaseView.Feature>.scope
    StoreOf<Integration.BasicsView.Feature>.scope
    BasicsView.body
    """)
  }
}
