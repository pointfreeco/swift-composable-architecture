//import TestCases
//import XCTest
//
//@MainActor
//final class PresentationTests: BaseIntegrationTests {
//  override func setUp() {
//    super.setUp()
//    self.app.buttons["Presentation"].tap()
//    self.clearLogs()
//  }
//
//  func testOptional() {
//    self.app.buttons["Present sheet"].tap()
//    self.app.buttons["Increment"].tap()
//    self.app.buttons["Dismiss"].firstMatch.tap()
//    self.assertLogs([
//      .unordered(
//        """
//        Store<ComposableArchitecture.PresentationState<Integration.BasicsView.Feature.State>, ComposableArchitecture.PresentationAction<Integration.BasicsView.Feature.Action>>.scope
//        Store<ComposableArchitecture.PresentationState<Integration.BasicsView.Feature.State>, ComposableArchitecture.PresentationAction<Integration.BasicsView.Feature.Action>>.scope
//        StoreOf<Integration.PresentationView.Feature>.scope
//        StoreOf<Integration.PresentationView.Feature>.scope
//        Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.init
//        Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.init
//        Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.init
//        Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.deinit
//        Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.init
//        Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.init
//        StoreOf<Integration.BasicsView.Feature>.init
//        StoreOf<Integration.BasicsView.Feature>.init
//        BasicsView.body
//        Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
//        Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
//        Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
//        Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
//        Store<ComposableArchitecture.PresentationState<Integration.BasicsView.Feature.State>, ComposableArchitecture.PresentationAction<Integration.BasicsView.Feature.Action>>.scope
//        Store<ComposableArchitecture.PresentationState<Integration.BasicsView.Feature.State>, ComposableArchitecture.PresentationAction<Integration.BasicsView.Feature.Action>>.scope
//        StoreOf<Integration.PresentationView.Feature>.scope
//        StoreOf<Integration.PresentationView.Feature>.scope
//        StoreOf<Integration.BasicsView.Feature>.scope
//        BasicsView.body
//        Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
//        StoreOf<Integration.BasicsView.Feature>.scope
//        Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
//        Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
//        Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
//        Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
//        Store<ComposableArchitecture.PresentationState<Integration.BasicsView.Feature.State>, ComposableArchitecture.PresentationAction<Integration.BasicsView.Feature.Action>>.scope
//        Store<ComposableArchitecture.PresentationState<Integration.BasicsView.Feature.State>, ComposableArchitecture.PresentationAction<Integration.BasicsView.Feature.Action>>.scope
//        StoreOf<Integration.PresentationView.Feature>.scope
//        StoreOf<Integration.PresentationView.Feature>.scope
//        StoreOf<Integration.PresentationView.Feature>.scope
//        StoreOf<Integration.PresentationView.Feature>.scope
//        Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.init
//        StoreOf<Integration.BasicsView.Feature>.deinit
//        Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.deinit
//        StoreOf<Integration.BasicsView.Feature>.deinit
//        Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.deinit
//        """)
//    ])
//  }
//
//  func testOptional_ObserveChildCount() {
//    self.app.buttons["Present sheet"].tap()
//    self.app.buttons["Observe child count"].tap()
//    self.app.buttons["Increment"].tap()
//    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)
//    self.app.buttons["Dismiss"].firstMatch.tap()
//    self.assertLogs([
//      .unordered("""
//      StoreOf<Integration.PresentationView.Feature>.scope
//      Store<ComposableArchitecture.PresentationState<Integration.BasicsView.Feature.State>, ComposableArchitecture.PresentationAction<Integration.BasicsView.Feature.Action>>.scope
//      Store<ComposableArchitecture.PresentationState<Integration.BasicsView.Feature.State>, ComposableArchitecture.PresentationAction<Integration.BasicsView.Feature.Action>>.scope
//      StoreOf<Integration.PresentationView.Feature>.scope
//      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.init
//      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.init
//      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.init
//      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.deinit
//      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.init
//      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.init
//      StoreOf<Integration.BasicsView.Feature>.init
//      StoreOf<Integration.BasicsView.Feature>.init
//      BasicsView.body
//      StoreOf<Integration.PresentationView.Feature>.scope
//      PresentationView.body
//      StoreOf<Integration.PresentationView.Feature>.scope
//      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
//      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
//      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
//      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
//      Store<ComposableArchitecture.PresentationState<Integration.BasicsView.Feature.State>, ComposableArchitecture.PresentationAction<Integration.BasicsView.Feature.Action>>.scope
//      Store<ComposableArchitecture.PresentationState<Integration.BasicsView.Feature.State>, ComposableArchitecture.PresentationAction<Integration.BasicsView.Feature.Action>>.scope
//      StoreOf<Integration.PresentationView.Feature>.scope
//      StoreOf<Integration.BasicsView.Feature>.scope
//      PresentationView.body
//      BasicsView.body
//      StoreOf<Integration.PresentationView.Feature>.scope
//      StoreOf<Integration.PresentationView.Feature>.scope
//      StoreOf<Integration.PresentationView.Feature>.scope
//      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
//      StoreOf<Integration.BasicsView.Feature>.scope
//      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
//      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
//      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
//      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.scope
//      Store<ComposableArchitecture.PresentationState<Integration.BasicsView.Feature.State>, ComposableArchitecture.PresentationAction<Integration.BasicsView.Feature.Action>>.scope
//      Store<ComposableArchitecture.PresentationState<Integration.BasicsView.Feature.State>, ComposableArchitecture.PresentationAction<Integration.BasicsView.Feature.Action>>.scope
//      StoreOf<Integration.PresentationView.Feature>.scope
//      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.init
//      PresentationView.body
//      StoreOf<Integration.BasicsView.Feature>.deinit
//      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.deinit
//      StoreOf<Integration.BasicsView.Feature>.deinit
//      Store<Swift.Optional<Integration.BasicsView.Feature.State>, Integration.BasicsView.Feature.Action>.deinit
//      """)
//    ])
//  }
//}
