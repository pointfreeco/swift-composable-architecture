import Perception
@_spi(Internals) import ComposableArchitecture
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

  func testObservation() {
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

  func testChangeUserDefaultsDirectly() async throws {
    @Dependency(\.defaultAppStorage) var defaults
    @Shared(.appStorage("count")) var count = 0

    try await Task.sleep(nanoseconds: 10_000_000)
    defaults.setValue(count + 42, forKey: "count")
    try await Task.sleep(nanoseconds: 100_000_000)
    XCTAssertEqual(count, 42)
  }

  func testDeleteUserDefault() async throws {
    @Dependency(\.defaultAppStorage) var defaults
    @Shared(.appStorage("count")) var count = 0
    count = 42

    try await Task.sleep(nanoseconds: 1_000_000)
    defaults.removeObject(forKey: "count")
    try await Task.sleep(nanoseconds: 1_000_000)
    XCTAssertEqual(count, 0)
  }

  func testKeyPath() async throws {
    try await withMainSerialExecutor {
      @Dependency(\.defaultAppStorage) var defaults
      @Shared(.appStorage(\.count)) var count = 0
      _ = count
      await Task.yield()

      defaults.count += 1
      try await Task.sleep(nanoseconds: 1_000_000)
      XCTAssertEqual(count, 1)
    }
  }
}

fileprivate extension UserDefaults {
  @objc dynamic var count: Int {
    get { integer(forKey: "count") }
    set { set(newValue, forKey: "count") }
  }
}
