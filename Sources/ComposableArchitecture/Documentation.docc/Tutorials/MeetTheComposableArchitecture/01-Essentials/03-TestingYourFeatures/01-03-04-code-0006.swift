import ComposableArchitecture
import XCTest

@MainActor
final class CounterFeatureTests: XCTestCase {
  func testNumberFact() async {
    let store = TestStore(initialState: CounterFeature.State()) {
      CounterFeature()
    }

    await store.send(.factButtonTapped) {
      $0.isLoading = true
    }
    await store.receive(\.factResponse, timeout: .seconds(1)) {
      $0.isLoading = false
      $0.fact = "???"
    }
    // ❌ @Dependency(\.numberFact) has no test implementation, but was
    //    accessed from a test context:
    //
    //   Location:
    //     TCATest/CounterFeature.swift:70
    //   Dependency:
    //     NumberFactClient
    //
    // Dependencies registered with the library are not allowed to use
    // their default, live implementations when run from tests.
  }
}
