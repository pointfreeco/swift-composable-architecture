@_spi(Internals) @_spi(Logging) import ComposableArchitecture
import XCTest

class BaseTCATestCase: XCTestCase {
  override func tearDown() async throws {
    try await super.tearDown()
    let description = "\(self)"
    _cancellationCancellables.withValue {
      XCTAssertEqual($0.count, 0, description)
      $0.removeAll()
    }
    await MainActor.run {
      Logger.shared.isEnabled = false
      Logger.shared.clear()
    }
  }
}
