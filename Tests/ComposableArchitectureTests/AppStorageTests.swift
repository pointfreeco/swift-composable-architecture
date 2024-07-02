@_spi(Internals) import ComposableArchitecture
import Perception
import XCTest

final class AppStorageTests: XCTestCase {
  func testBasics() {
    @Dependency(\.defaultAppStorage) var defaults
    @Shared(.appStorage("count")) var count = 0
    XCTAssertEqual(count, 0)
    XCTAssertEqual(defaults.integer(forKey: "count"), 0)

    count += 1
    XCTAssertEqual(count, 1)
    XCTAssertEqual(defaults.integer(forKey: "count"), 1)
  }

  func testDefaultsRegistered() {
    @Dependency(\.defaultAppStorage) var defaults
    @Shared(.appStorage("count")) var count = 42
    XCTAssertEqual(defaults.integer(forKey: "count"), 42)

    count += 1
    XCTAssertEqual(count, 43)
    XCTAssertEqual(defaults.integer(forKey: "count"), 43)
  }

  func testDefaultsReadURL() {
    @Dependency(\.defaultAppStorage) var defaults
    defaults.set(URL(string: "https://pointfree.co"), forKey: "url")
    @Shared(.appStorage("url")) var url: URL?
    XCTAssertEqual(url, URL(string: "https://pointfree.co"))
  }

  func testDefaultsRegistered_URL() {
    @Dependency(\.defaultAppStorage) var defaults
    @Shared(.appStorage("url")) var url: URL = URL(string: "https://pointfree.co")!
    XCTAssertEqual(defaults.url(forKey: "url"), URL(string: "https://pointfree.co")!)

    url = URL(string: "https://example.com")!
    XCTAssertEqual(url, URL(string: "https://example.com")!)
    XCTAssertEqual(defaults.url(forKey: "url"), URL(string: "https://example.com")!)
  }

  func testDefaultsRegistered_Optional_URL() {
    @Dependency(\.defaultAppStorage) var defaults
    @Shared(.appStorage("url")) var url: URL? = URL(string: "https://pointfree.co")
    XCTAssertEqual(defaults.url(forKey: "url"), URL(string: "https://pointfree.co"))

    url = URL(string: "https://example.com")!
    XCTAssertEqual(url, URL(string: "https://example.com"))
    XCTAssertEqual(defaults.url(forKey: "url"), URL(string: "https://example.com"))
  }

  func testDefaultsRegistered_Optional() {
    @Dependency(\.defaultAppStorage) var defaults
    @Shared(.appStorage("data")) var data: Data?
    XCTAssertEqual(defaults.data(forKey: "data"), nil)

    data = Data()
    XCTAssertEqual(data, Data())
    XCTAssertEqual(defaults.data(forKey: "data"), Data())
  }

  func testDefaultsRegistered_RawRepresentable() {
    enum Direction: String, CaseIterable {
      case north, south, east, west
    }
    @Dependency(\.defaultAppStorage) var defaults
    @Shared(.appStorage("direction")) var direction: Direction = .north
    XCTAssertEqual(defaults.string(forKey: "direction"), "north")

    direction = .south
    XCTAssertEqual(defaults.string(forKey: "direction"), "south")
  }

  func testDefaultsRegistered_Optional_RawRepresentable() {
    enum Direction: String, CaseIterable {
      case north, south, east, west
    }
    @Dependency(\.defaultAppStorage) var defaults
    @Shared(.appStorage("direction")) var direction: Direction?
    XCTAssertEqual(defaults.string(forKey: "direction"), nil)

    direction = .south
    XCTAssertEqual(defaults.string(forKey: "direction"), "south")
  }

  func testDefaultAppStorageOverride() {
    let defaults = UserDefaults(suiteName: "tests")!
    defaults.removePersistentDomain(forName: "tests")

    withDependencies {
      $0.defaultAppStorage = defaults
    } operation: {
      @Shared(.appStorage("count")) var count = 0
      count += 1
      XCTAssertEqual(defaults.integer(forKey: "count"), 1)
    }

    @Dependency(\.defaultAppStorage) var defaultAppStorage
    XCTAssertNotEqual(defaultAppStorage, defaults)
    XCTAssertEqual(defaultAppStorage.integer(forKey: "count"), 0)
  }

  func testObservation_DirectMutation() {
    @Shared(.appStorage("count")) var count = 0
    let countDidChange = self.expectation(description: "countDidChange")
    withPerceptionTracking {
      _ = count
    } onChange: {
      countDidChange.fulfill()
    }
    count += 1
    self.wait(for: [countDidChange], timeout: 0)
  }

  func testObservation_ExternalMutation() {
    @Dependency(\.defaultAppStorage) var defaults
    @Shared(.appStorage("count")) var count = 0
    let didChange = self.expectation(description: "didChange")

    withPerceptionTracking {
      _ = count
    } onChange: { [count = $count] in
      XCTAssertEqual(count.wrappedValue, 0)
      didChange.fulfill()
    }

    defaults.setValue(42, forKey: "count")
    self.wait(for: [didChange], timeout: 0)
    XCTAssertEqual(count, 42)
  }

  func testChangeUserDefaultsDirectly() {
    @Dependency(\.defaultAppStorage) var defaults
    @Shared(.appStorage("count")) var count = 0
    defaults.setValue(count + 42, forKey: "count")
    XCTAssertEqual(count, 42)
  }

  func testChangeUserDefaultsDirectly_RawRepresentable() {
    enum Direction: String, CaseIterable {
      case north, south, east, west
    }
    @Dependency(\.defaultAppStorage) var defaults
    @Shared(.appStorage("direction")) var direction: Direction = .south
    defaults.set("east", forKey: "direction")
    XCTAssertEqual(direction, .east)
  }

  func testChangeUserDefaultsDirectly_KeyWithPeriod() {
    @Dependency(\.defaultAppStorage) var defaults
    @Shared(.appStorage("pointfreeco.count")) var count = 0
    defaults.setValue(count + 42, forKey: "pointfreeco.count")
    XCTAssertEqual(count, 42)
  }

  func testDeleteUserDefault() {
    @Dependency(\.defaultAppStorage) var defaults
    @Shared(.appStorage("count")) var count = 0
    count = 42
    defaults.removeObject(forKey: "count")
    XCTAssertEqual(count, 0)
  }

  func testKeyPath() {
    @Dependency(\.defaultAppStorage) var defaults
    @Shared(.appStorage(\.count)) var count = 0
    defaults.count += 1
    XCTAssertEqual(count, 1)
  }

  func testOptionalInitializers() {
    @Shared(.appStorage("count1")) var count1: Int?
    XCTAssertEqual(count1, nil)
    @Shared(.appStorage("count")) var count2: Int? = nil
    XCTAssertEqual(count2, nil)
  }

  func testOptionalInitializers_URL() {
    @Shared(.appStorage("url1")) var url1: URL?
    XCTAssertEqual(url1, nil)
    @Shared(.appStorage("url2")) var url2: URL? = nil
    XCTAssertEqual(url2, nil)
  }

  func testRemoveDuplicates() {
    @Dependency(\.defaultAppStorage) var store
    @Shared(.appStorage("count")) var count = 0

    let values = LockIsolated([Int]())
    let cancellable = $count
      .publisher
      .sink { count in values.withValue { $0.append(count) } }
    defer { _ = cancellable }

    count += 1
    XCTAssertEqual(values.value, [1])

    store.setValue(2, forKey: "other-count")
    XCTAssertEqual(values.value, [1])
  }

  @MainActor
  func testUpdateStoreFromBackgroundThread() async throws {
    @Dependency(\.defaultAppStorage) var store
    @Shared(.appStorage("count")) var count = 0

    let publisherExpectation = expectation(description: "publisher")
    let cancellable = $count.publisher.sink { _ in
      XCTAssertTrue(Thread.isMainThread)
      publisherExpectation.fulfill()
    }
    defer { _ = cancellable }

    await withUnsafeContinuation { continuation in
      DispatchQueue.global().async { [store = UncheckedSendable(store)] in
        XCTAssertFalse(Thread.isMainThread)
        store.wrappedValue.setValue(1, forKey: "count")
        continuation.resume()
      }
    }

    await fulfillment(of: [publisherExpectation], timeout: 0)
  }

  @MainActor
  func testUpdateStoreFromMainThread() async throws {
    @Dependency(\.defaultAppStorage) var store
    @Shared(.appStorage("count")) var count = 0
    let isInStackFrame = LockIsolated(false)

    let publisherExpectation = expectation(description: "publisher")
    let cancellable = $count.publisher.sink { _ in
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertTrue(isInStackFrame.value)
      publisherExpectation.fulfill()
    }
    defer { _ = cancellable }

    await withUnsafeContinuation { continuation in
      XCTAssertTrue(Thread.isMainThread)
      isInStackFrame.withValue { $0 = true }
      store.setValue(1, forKey: "count")
      isInStackFrame.withValue { $0 = false }
      continuation.resume()
    }

    await fulfillment(of: [publisherExpectation], timeout: 0)
  }

  @MainActor
  func testWillEnterForegroundFromBackgroundThread() async throws {
    @Shared(.appStorage("count")) var count = 0

    let publisherExpectation = expectation(description: "publisher")
    let cancellable = $count.publisher.sink { _ in
      XCTAssertTrue(Thread.isMainThread)
      publisherExpectation.fulfill()
    }
    defer { _ = cancellable }

    await withUnsafeContinuation { continuation in
      DispatchQueue.global().async {
        XCTAssertFalse(Thread.isMainThread)
        NotificationCenter.default.post(name: willEnterForegroundNotificationName!, object: nil)
        continuation.resume()
      }
    }

    await fulfillment(of: [publisherExpectation], timeout: 0)
  }

  @MainActor
  func testUpdateStoreFromBackgroundThread_KeyPath() async throws {
    @Dependency(\.defaultAppStorage) var store
    @Shared(.appStorage(\.count)) var count = 0

    let publisherExpectation = expectation(description: "publisher")
    publisherExpectation.expectedFulfillmentCount = 2
    let cancellable = $count.publisher.sink { _ in
      XCTAssertTrue(Thread.isMainThread)
      publisherExpectation.fulfill()
    }
    defer { _ = cancellable }

    await withUnsafeContinuation { continuation in
      DispatchQueue.global().async { [store = UncheckedSendable(store)] in
        XCTAssertFalse(Thread.isMainThread)
        store.wrappedValue.count = 1
        continuation.resume()
      }
    }

    await fulfillment(of: [publisherExpectation], timeout: 0)
  }
}

extension UserDefaults {
  @objc fileprivate dynamic var count: Int {
    get { integer(forKey: "count") }
    set { set(newValue, forKey: "count") }
  }
}
