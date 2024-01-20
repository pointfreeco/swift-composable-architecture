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

  func testObsevation() {
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

  func testNotifications() async throws {
    // NB: Need to use a non-persisting defaults to reliably get change notifications.
    let defaults = UserDefaults(suiteName: "test")!
    try await withDependencies {
      $0.defaultAppStorage = defaults
    } operation: {
      @Shared(.appStorage("count")) var count = 0
      // NB: This is required to register for notifications
      _ = count
      count = 0

      defaults.setValue(count + 42, forKey: "count")
      try await Task.sleep(nanoseconds: 1_000_000)
      XCTAssertEqual(count, 42)
    }
  }
}
