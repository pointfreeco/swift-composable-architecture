import ComposableArchitectureTestSupport
import XCTest

final class ComposableArchitectureTestSupportTests: XCTestCase {
  func testBasics() {
    let store = TestStore(
      initialState: 0,
      reducer: Reduce<Int, Void> { state, _ in
        state += 1
        return .none
      }
    )
    
    store.send(()) {
      $0 = 0
    }
  }
}
