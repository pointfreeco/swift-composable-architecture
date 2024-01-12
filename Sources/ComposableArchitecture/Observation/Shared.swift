import Foundation

@Perceptible
@dynamicMemberLookup
@propertyWrapper
public final class Shared<Value> {
  private var currentValue: Value
  fileprivate var snapshot: Value?
  private let lock = NSRecursiveLock()

  public var wrappedValue: Value {
    get {
      self.lock.sync {
        if SharedLocals.isAsserting {
          self.snapshot ?? self.currentValue
        } else {
          self.currentValue
        }
      }
    }
    set {
      self.lock.sync {
        @Dependency(\.sharedChangeTracker) var sharedChangeTracker
        if let sharedChangeTracker {
          if SharedLocals.isAsserting {
            self.snapshot = newValue
          } else {
            if self.snapshot == nil {
              self.snapshot = self.currentValue
            }
            self.currentValue = newValue
            sharedChangeTracker.track(self)
          }
        } else {
          self.currentValue = newValue
          self.snapshot = nil
        }
      }
    }
  }

  public var projectedValue: Shared {
    self
  }

  public init(_ value: Value) {
    self.currentValue = value
  }

  public subscript<Member>(dynamicMember keyPath: WritableKeyPath<Value, Member>) -> Member {
    get { self.wrappedValue[keyPath: keyPath] }
    set { self.wrappedValue[keyPath: keyPath] = newValue }
  }

  public func copy() -> Shared {
    Shared(self.wrappedValue)
  }

  public func assert(
    _ updateValueToExpectedResult: (inout Value) throws -> Void,
    file: StaticString = #file,
    line: UInt = #line
  ) rethrows where Value: Equatable {
    guard var snapshot = self.snapshot, snapshot != self.currentValue else {
      XCTFail("Expected changes, but none occurred.", file: file, line: line)
      return
    }
    try updateValueToExpectedResult(&snapshot)
    self.snapshot = snapshot
    XCTAssertNoDifference(self.currentValue, self.snapshot, file: file, line: line)
    self.snapshot = nil
  }
}

// TODO: Write tests that try to break equatable/hashable invariants.

extension Shared: Equatable where Value: Equatable {
  public static func == (lhs: Shared, rhs: Shared) -> Bool {
    if SharedLocals.isAsserting, lhs === rhs {
      return lhs.snapshot ?? lhs.currentValue == rhs.currentValue
    } else {
      return lhs.wrappedValue == rhs.wrappedValue
    }
  }
}

extension Shared: Hashable where Value: Hashable {
  public func hash(into hasher: inout Hasher) {
    // TODO: hasher.combine(ObjectIdentifier(self))
    hasher.combine(self.wrappedValue)
  }
}

extension Shared: Identifiable where Value: Identifiable {
  public var id: Value.ID {
    self.wrappedValue.id
  }
}

extension Shared: Decodable where Value: Decodable {
  public convenience init(from decoder: Decoder) throws {
    do {
      self.init(try decoder.singleValueContainer().decode(Value.self))
    } catch {
      self.init(try .init(from: decoder))
    }
  }
}

extension Shared: Encodable where Value: Encodable {
  public func encode(to encoder: Encoder) throws {
    do {
      var container = encoder.singleValueContainer()
      try container.encode(self.wrappedValue)
    } catch {
      try self.wrappedValue.encode(to: encoder)
    }
  }
}

extension Shared: _CustomDiffObject {
  public var _customDiffValues: (Any, Any) {
    (self.snapshot ?? self.currentValue, self.currentValue)
  }
}

extension Shared: @unchecked Sendable where Value: Sendable {}

extension Shared: TestDependencyKey where Value: TestDependencyKey {
  public static var testValue: Shared<Value.Value> {
    Shared<Value.Value>(Value.testValue)
  }
}
extension Shared: DependencyKey where Value: DependencyKey {
  public static var liveValue: Shared<Value.Value> {
    Shared<Value.Value>(Value.liveValue)
  }
}

enum SharedLocals {
  @TaskLocal static var isAsserting = false
}

final class SharedChangeTracker: @unchecked Sendable {
  private var changed = LockIsolated<[ObjectIdentifier: () -> Void]>([:])
  var hasChanges: Bool { !self.changed.value.isEmpty }
  func track<T>(_ shared: Shared<T>) {
    self.changed.withValue {
      _ = $0[ObjectIdentifier(shared)] = { [weak shared] in
        shared?.snapshot = nil
      }
    }
  }
  func reset() {
    self.changed.withValue {
      for reset in $0.values {
        reset()
      }
      $0.removeAll()
    }
  }
}

struct SharedChangeTrackerKey: DependencyKey {
  static let liveValue: SharedChangeTracker? = nil
  static let testValue: SharedChangeTracker? = nil
}

extension DependencyValues {
  var sharedChangeTracker: SharedChangeTracker? {
    get { self[SharedChangeTrackerKey.self] }
    set { self[SharedChangeTrackerKey.self] = newValue }
  }
}
