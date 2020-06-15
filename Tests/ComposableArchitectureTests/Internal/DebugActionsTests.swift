import Combine
import XCTest

@testable import ComposableArchitecture

private enum Action: Equatable {
  case one
  case two(a: Int)
  case three(b: [Int])
}


final class DebugActionsTests: XCTestCase {

  func testThrottleLatest() {

    var prints = [String]()
    let expectWait1 = expectation(description: "Waiting...")
    let expectWait2 = expectation(description: "Waiting...")
    let expectWait3 = expectation(description: "Waiting...")

    let reducer = Reducer<Int, Action, Void>{ (state, _, _) in
      state += 1
      return .none
    }
      .debugActionLabels(environment: { DebugEnvironment(printer: { prints.append($0) }) })

    let store = TestStore(initialState: 0, reducer: reducer, environment: ())

    store.assert(
      .send(.one) { $0 = 1},
      .do { XCTWaiter().wait(for: [expectWait1], timeout: 0.02) },
      .do { XCTAssertEqual(prints, ["Action: .one"]) },

      .send(.two(a: 2)) { $0 = 2},
      .do { XCTWaiter().wait(for: [expectWait2], timeout: 0.02) },
      .do { XCTAssertEqual(prints, ["Action: .one", "Action: .two(a: 2)"]) },

      .send(.three(b: [1, 2, 3])) { $0 = 3},
      .do { XCTWaiter().wait(for: [expectWait3], timeout: 0.02) },
      .do { XCTAssertEqual(prints, ["Action: .one", "Action: .two(a: 2)", "Action: .three(b: [...])"]) }
    )
  }
}
