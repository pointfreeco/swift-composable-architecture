import ComposableArchitecture
@testable import SwiftUICaseStudies
import XCTest

class RefreshableTests: XCTestCase {
  func testTca() {
    let store = TestStore(
      initialState: .init(),
      reducer: pullToRefreshReducer,
      environment: .init(
        fact: .init(fetch: { .init(value: "\($0) is a good number.") }),
        mainQueue: .immediate
      )
    )
    
    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.refresh) {
      $0.isLoading = true
    }
    store.receive(.factResponse(.success("1 is a good number."))) {
      $0.isLoading = false
      $0.fact = "1 is a good number."
    }
  }
  
  func testTca_Cancellation() {
    let mainQueue = DispatchQueue.test
    let store = TestStore(
      initialState: .init(),
      reducer: pullToRefreshReducer,
      environment: .init(
        fact: .init(fetch: { .init(value: "\($0) is a good number.") }),
        mainQueue: mainQueue.eraseToAnyScheduler()
      )
    )
    
    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.refresh) {
      $0.isLoading = true
    }
    store.send(.cancelButtonTapped) {
      $0.isLoading = false
    }
  }

  func testVanilla() async {
    let viewModel = PullToRefreshViewModel(
      fetch: { count in
        await Task.sleep(20_000_000)
        return "\(count) is a good number."
      }
    )

    viewModel.incrementButtonTapped()
    XCTAssertEqual(viewModel.count, 1)

    XCTAssertEqual(viewModel.isLoading, false)
    let task = Task {
      await viewModel.getFact()
    }
    await Task.sleep(10_000_000)
    XCTAssertEqual(viewModel.isLoading, true)
    await task.value
    XCTAssertEqual(viewModel.fact, "1 is a good number.")
    XCTAssertEqual(viewModel.isLoading, false)
  }
}
