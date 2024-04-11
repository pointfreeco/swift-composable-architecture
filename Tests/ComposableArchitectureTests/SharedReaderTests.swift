import Combine
import ComposableArchitecture
import XCTest

final class SharedReaderTests: XCTestCase {
  @MainActor
  func testSharedReader() {
    @Shared(0) var count: Int
    let countReader = $count.reader

    count += 1
    XCTAssertEqual(count, 1)
    XCTAssertEqual(countReader.wrappedValue, 1)
  }
}
