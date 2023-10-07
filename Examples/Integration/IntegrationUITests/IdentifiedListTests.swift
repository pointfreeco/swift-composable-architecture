//import TestCases
//import XCTest
//
//@MainActor
//final class IdentifiedListTests: BaseIntegrationTests {
//  override func setUp() {
//    super.setUp()
//    self.app.buttons["Identified list"].tap()
//    self.clearLogs()
//  }
//
//  func testBasics() {
//    self.app.buttons["Add"].tap()
//    self.assertLogs([
//      .unordered("""
//      StoreOf<Integration.IdentifiedListView.Feature>.scope
//      Store<IdentifiedCollections.IdentifiedArray<Foundation.UUID, Integration.BasicsView.Feature.State>, (Foundation.UUID, Integration.BasicsView.Feature.Action)>.scope
//      StoreOf<Integration.IdentifiedListView.Feature>.scope
//      Store<IdentifiedCollections.IdentifiedArray<Foundation.UUID, Integration.BasicsView.Feature.State>, (Foundation.UUID, Integration.BasicsView.Feature.Action)>.init
//      Store<IdentifiedCollections.IdentifiedArray<Foundation.UUID, Integration.BasicsView.Feature.State>, (Foundation.UUID, Integration.BasicsView.Feature.Action)>.init
//      Store<IdentifiedCollections.IdentifiedArray<Foundation.UUID, Integration.BasicsView.Feature.State>, (Foundation.UUID, Integration.BasicsView.Feature.Action)>.deinit
//      Store<IdentifiedCollections.IdentifiedArray<Foundation.UUID, Integration.BasicsView.Feature.State>, (Foundation.UUID, Integration.BasicsView.Feature.Action)>.deinit
//      StoreOf<Integration.BasicsView.Feature>.init
//      Store<Foundation.UUID, Integration.BasicsView.Feature.Action>.init
//      Store<Foundation.UUID, Integration.BasicsView.Feature.Action>.init
//      StoreOf<Integration.BasicsView.Feature>.init
//      Store<Foundation.UUID, Integration.BasicsView.Feature.Action>.init
//      Store<Foundation.UUID, Integration.BasicsView.Feature.Action>.init
//      Store<Foundation.UUID, Integration.BasicsView.Feature.Action>.deinit
//      Store<Foundation.UUID, Integration.BasicsView.Feature.Action>.deinit
//      StoreOf<Integration.BasicsView.Feature>.deinit
//      StoreOf<Integration.BasicsView.Feature>.init
//      BasicsView.body
//      """)
//    ])
//  }
//
//  func testAddTwoIncrementFirst() {
//    self.app.buttons["Add"].tap()
//    self.app.buttons["Add"].tap()
//    self.clearLogs()
//    self.app.buttons["Increment"].firstMatch.tap()
//    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)
//    self.assertLogs([
//      .unordered("""
//      Store<Foundation.UUID, Integration.BasicsView.Feature.Action>.scope
//      StoreOf<Integration.BasicsView.Feature>.scope
//      Store<IdentifiedCollections.IdentifiedArray<Foundation.UUID, Integration.BasicsView.Feature.State>, (Foundation.UUID, Integration.BasicsView.Feature.Action)>.scope
//      Store<IdentifiedCollections.IdentifiedArray<Foundation.UUID, Integration.BasicsView.Feature.State>, (Foundation.UUID, Integration.BasicsView.Feature.Action)>.scope
//      Store<Foundation.UUID, Integration.BasicsView.Feature.Action>.scope
//      StoreOf<Integration.BasicsView.Feature>.scope
//      StoreOf<Integration.BasicsView.Feature>.scope
//      Store<IdentifiedCollections.IdentifiedArray<Foundation.UUID, Integration.BasicsView.Feature.State>, (Foundation.UUID, Integration.BasicsView.Feature.Action)>.scope
//      StoreOf<Integration.IdentifiedListView.Feature>.scope
//      StoreOf<Integration.IdentifiedListView.Feature>.scope
//      StoreOf<Integration.BasicsView.Feature>.scope
//      BasicsView.body
//      Store<IdentifiedCollections.IdentifiedArray<Foundation.UUID, Integration.BasicsView.Feature.State>, (Foundation.UUID, Integration.BasicsView.Feature.Action)>.init
//      Store<IdentifiedCollections.IdentifiedArray<Foundation.UUID, Integration.BasicsView.Feature.State>, (Foundation.UUID, Integration.BasicsView.Feature.Action)>.init
//      Store<IdentifiedCollections.IdentifiedArray<Foundation.UUID, Integration.BasicsView.Feature.State>, (Foundation.UUID, Integration.BasicsView.Feature.Action)>.deinit
//      StoreOf<Integration.BasicsView.Feature>.init
//      Store<Foundation.UUID, Integration.BasicsView.Feature.Action>.init
//      Store<Foundation.UUID, Integration.BasicsView.Feature.Action>.init
//      StoreOf<Integration.BasicsView.Feature>.init
//      Store<Foundation.UUID, Integration.BasicsView.Feature.Action>.init
//      Store<Foundation.UUID, Integration.BasicsView.Feature.Action>.init
//      StoreOf<Integration.BasicsView.Feature>.init
//      StoreOf<Integration.BasicsView.Feature>.deinit
//      BasicsView.body
//      Store<Foundation.UUID, Integration.BasicsView.Feature.Action>.deinit
//      Store<Foundation.UUID, Integration.BasicsView.Feature.Action>.deinit
//      StoreOf<Integration.BasicsView.Feature>.init
//      StoreOf<Integration.BasicsView.Feature>.deinit
//      BasicsView.body
//      Store<Foundation.UUID, Integration.BasicsView.Feature.Action>.deinit
//      Store<Foundation.UUID, Integration.BasicsView.Feature.Action>.deinit
//      StoreOf<Integration.BasicsView.Feature>.deinit
//      """)
//    ])
//  }
//
//  func testAddTwoIncrementSecond() {
//    self.app.buttons["Add"].tap()
//    self.app.buttons["Add"].tap()
//    self.clearLogs()
//    self.app.cells.element(boundBy: 2).buttons["Increment"].tap()
//    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)
//    self.assertLogs([
//      .unordered("""
//      StoreOf<Integration.IdentifiedListView.Feature>.scope
//      Store<IdentifiedCollections.IdentifiedArray<Foundation.UUID, Integration.BasicsView.Feature.State>, (Foundation.UUID, Integration.BasicsView.Feature.Action)>.scope
//      StoreOf<Integration.BasicsView.Feature>.scope
//      Store<IdentifiedCollections.IdentifiedArray<Foundation.UUID, Integration.BasicsView.Feature.State>, (Foundation.UUID, Integration.BasicsView.Feature.Action)>.scope
//      Store<Foundation.UUID, Integration.BasicsView.Feature.Action>.scope
//      StoreOf<Integration.BasicsView.Feature>.scope
//      Store<IdentifiedCollections.IdentifiedArray<Foundation.UUID, Integration.BasicsView.Feature.State>, (Foundation.UUID, Integration.BasicsView.Feature.Action)>.scope
//      StoreOf<Integration.IdentifiedListView.Feature>.scope
//      StoreOf<Integration.BasicsView.Feature>.scope
//      Store<Foundation.UUID, Integration.BasicsView.Feature.Action>.scope
//      StoreOf<Integration.BasicsView.Feature>.scope
//      BasicsView.body
//      """)
//    ])
//  }
//}
