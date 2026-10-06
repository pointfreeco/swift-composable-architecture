import ComposableArchitecture
import XCTest

final class CasePathIterableTests: BaseTCATestCase {
  @CasePathable
  enum Child {
    case tapped
    case named(String)
  }

  func testPresentationAction() {
    let paths = Array(PresentationAction<Child>.allCasePaths)
    XCTAssertEqual(paths, [\.dismiss, \.presented])
    XCTAssertEqual(PresentationAction<Child>.allCasePaths[.dismiss], \.dismiss)
    XCTAssertEqual(PresentationAction<Child>.allCasePaths[.presented(.tapped)], \.presented)
  }

  func testIdentifiedAction() {
    let paths = Array(IdentifiedAction<Int, Child>.allCasePaths)
    XCTAssertEqual(paths, [\.element])
    XCTAssertEqual(
      IdentifiedAction<Int, Child>.allCasePaths[.element(id: 1, action: .tapped)], \.element)
  }

  func testStackAction() {
    let paths = Array(StackAction<Int, Child>.allCasePaths)
    XCTAssertEqual(paths, [\.element, \.popFrom, \.push])
    XCTAssertEqual(StackAction<Int, Child>.allCasePaths[.popFrom(id: StackElementID(0))], \.popFrom)
    XCTAssertEqual(
      StackAction<Int, Child>.allCasePaths[.push(id: StackElementID(0), state: 1)], \.push)
  }

  func testGenericWalkReachesThroughWrappers() {
    func caseCount<Root: CasePathIterable>(_: Root.Type) -> Int {
      Root.allCasePaths.reduce(0) { count, _ in count + 1 }
    }
    XCTAssertEqual(caseCount(Child.self), 2)
    XCTAssertEqual(caseCount(PresentationAction<Child>.self), 2)
    XCTAssertEqual(caseCount(IdentifiedAction<Int, Child>.self), 1)
    XCTAssertEqual(caseCount(StackAction<Int, Child>.self), 3)
  }
}
