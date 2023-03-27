import ComposableArchitecture
import XCTest

@available(*, deprecated)
final class DeprecatedTests: BaseTCATestCase {
  func testUncheckedStore() {
    var expectations: [XCTestExpectation] = []
    for n in 1...100 {
      let expectation = XCTestExpectation(description: "\(n)th iteration is complete")
      expectations.append(expectation)
      DispatchQueue.global().async {
        let viewStore = ViewStore(
          Store.unchecked(
            initialState: 0,
            reducer: AnyReducer<Int, Void, XCTestExpectation> { state, _, expectation in
              state += 1
              if state == 2 {
                return .fireAndForget { expectation.fulfill() }
              }
              return .none
            },
            environment: expectation
          )
        )
        viewStore.send(())
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
          viewStore.send(())
        }
      }
    }

    wait(for: expectations, timeout: 1)
  }
}
