import Combine
import ComposableArchitecture
import XCTest

final class SharedReaderTests: XCTestCase {
  @MainActor
  func testSharedReader() {
    @Shared var count: Int
    _count = Shared(0)
    let countReader = $count.reader

    count += 1
    XCTAssertEqual(count, 1)
    XCTAssertEqual(countReader.wrappedValue, 1)
  }
}
