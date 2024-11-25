import Combine
import ComposableArchitecture
import XCTest

final class SharedReaderTests: XCTestCase {
  func testSharedReader() {
    @Shared var count: Int
    _count = Shared(value: 0)
    let countReader = SharedReader($count)

    $count.withLock { $0 += 1 }
    XCTAssertEqual(count, 1)
    XCTAssertEqual(countReader.wrappedValue, 1)
  }
}
