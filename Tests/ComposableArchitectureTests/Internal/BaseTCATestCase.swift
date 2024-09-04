@_spi(Internals) @_spi(Logging) import ComposableArchitecture
import XCTest

class BaseTCATestCase: XCTestCase {
  override func tearDown() async throws {
    try await super.tearDown()
    _cancellationCancellables.withValue { [description = "\(self)"] in
      XCTAssertEqual($0.count, 0, description)
      $0.removeAll()
    }
    await MainActor.run {
      Logger.shared.isEnabled = false
      Logger.shared.clear()
    }
  }
}
