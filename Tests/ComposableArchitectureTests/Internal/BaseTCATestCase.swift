@_spi(Internals) @_spi(Logging) import ComposableArchitecture
import XCTest

class BaseTCATestCase: XCTestCase {
  override func tearDown() async throws {
    try await super.tearDown()
    XCTAssertEqual(_cancellationCancellables.count, 0, "\(self)")
    _cancellationCancellables.removeAll()
    await MainActor.run {
      Logger.shared.isEnabled = false
      Logger.shared.clear()
    }
  }
}
