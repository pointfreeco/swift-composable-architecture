@testable import SwiftUICaseStudies
import XCTest

class RefreshableTests: XCTestCase {

  func testVanilla() async {
    let viewModel = PullToRefreshViewModel(
      fetch: {
        await Task.sleep(10_000_000)
        return "\($0) is a good number."
      }
    )

    viewModel.incrementButtonTapped()
    XCTAssertEqual(viewModel.count, 1)


    let task = Task {
      await viewModel.getFact()
    }
    await Task.sleep(5_000_000)
    XCTAssertEqual(viewModel.isLoading, true)
    await task.value
    XCTAssertEqual(viewModel.fact, "1 is a good number.")
    XCTAssertEqual(viewModel.isLoading, false)
  }

  func testVanilla_Cancellation() async {
    let viewModel = PullToRefreshViewModel(
      fetch: {
        await Task.sleep(10_000_000)
        return "\($0) is a good number."
      }
    )

    viewModel.incrementButtonTapped()
    XCTAssertEqual(viewModel.count, 1)


    let task = Task {
      await viewModel.getFact()
    }
    await Task.sleep(5_000_000)
    XCTAssertEqual(viewModel.isLoading, true)
    task.cancel()
    XCTAssertNil(viewModel.fact)
    XCTAssertEqual(viewModel.isLoading, false)
  }
}
