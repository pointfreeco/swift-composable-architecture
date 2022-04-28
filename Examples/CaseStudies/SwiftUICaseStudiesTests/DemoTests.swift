import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
class DemoTests: XCTestCase {
  func testBasics() {
    let store = TestStore(
      initialState: .init(),
      reducer: reducer,
      environment: .init(
        number: .init(
          fact: { "\($0) is a good number" },
          random: {
            fatalError()
          }
        )
      )
    )

    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.incrementButtonTapped) {
      $0.count = 2
    }
    store.send(.factButtonTaped)
    store.receive(.factResponse("2 is a good number")) {
      $0.fact = "2 is a good number"
    }
  }
}
