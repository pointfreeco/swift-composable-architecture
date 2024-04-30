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
}

extension UserDefaults {
  @objc fileprivate dynamic var count: Int {
    get { integer(forKey: "count") }
    set { set(newValue, forKey: "count") }
  }
}
