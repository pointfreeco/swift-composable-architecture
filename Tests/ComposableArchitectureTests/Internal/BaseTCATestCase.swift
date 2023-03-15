import XCTest

@_spi(Internals) import ComposableArchitecture

class BaseTCATestCase: XCTestCase {
  override func tearDown() {
    super.tearDown()
    XCTAssertEqual(_cancellables.count, 0)
  }
}
