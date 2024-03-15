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

  func testChangeUserDefaultsDirectly() {
    @Dependency(\.defaultAppStorage) var defaults
    @Shared(.appStorage("count")) var count = 0
    defaults.setValue(count + 42, forKey: "count")
    XCTAssertEqual(count, 42)
  }

  func testDeleteUserDefault() {
    @Dependency(\.defaultAppStorage) var defaults
    @Shared(.appStorage("count")) var count = 0
    count = 42
    defaults.removeObject(forKey: "count")
    XCTAssertEqual(count, 0)
  }

  func testKeyPath() async throws {
    @Dependency(\.defaultAppStorage) var defaults
    @Shared(.appStorage(\.count)) var count = 0
    defaults.count += 1
    XCTAssertEqual(count, 1)
  }
}

extension UserDefaults {
  @objc fileprivate dynamic var count: Int {
    get { integer(forKey: "count") }
    set { set(newValue, forKey: "count") }
  }
}
