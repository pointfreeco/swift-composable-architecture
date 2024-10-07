import Combine
import ComposableArchitecture
import XCTest

final class SharedReaderTests: XCTestCase {
  func testSharedReader() {
    @Shared var count: Int
    _count = Shared(0)
    let countReader = $count.reader

    count += 1
    XCTAssertEqual(count, 1)
    XCTAssertEqual(countReader.wrappedValue, 1)
  }

  final class DeinitKey<Value: Sendable>: PersistenceKey, HashableObject {
    let value: Value?
    let onDeinit: @Sendable () -> Void
    init(_ value: Value? = nil, onDeinit: @escaping @Sendable () -> Void) {
      self.value = value
      self.onDeinit = onDeinit
    }
    deinit {
      onDeinit()
    }
    func load(initialValue: Value?) -> Value? { value ?? initialValue }
    func save(_ value: Value) {}
  }

  func testLifecycle() {
    let didDeinit = LockIsolated(false)
    do {
      @SharedReader(DeinitKey { didDeinit.setValue(true) }) var count = 0
    }
    XCTAssertTrue(didDeinit.value)
  }

  func testLifecycle_derived() {
    struct Count {
      var value = 0
    }
    var child: SharedReader<Int>?
    let didDeinit = LockIsolated(false)
    do {
      do {
        @SharedReader(DeinitKey { didDeinit.setValue(true) }) var count = Count()
        child = $count.value
      }
      XCTAssertFalse(didDeinit.value)
      child = nil
    }
    XCTAssertNil(child)
    XCTAssertTrue(didDeinit.value)
  }

  func testLifecycle_throwing() throws {
    let didDeinit = LockIsolated(false)
    do {
      @SharedReader var count: Int
      _count = try SharedReader(DeinitKey(42) { didDeinit.setValue(true) })
    }
    XCTAssertTrue(didDeinit.value)
  }

  func testLifecycle_InMemoryKey() {
    do {
      @Shared(.inMemory("count")) var count = 0
      count += 1
      XCTAssertEqual(1, count)
    }

    do {
      @SharedReader(.inMemory("count")) var count = 0
      XCTAssertEqual(1, count)
    }
  }
}
