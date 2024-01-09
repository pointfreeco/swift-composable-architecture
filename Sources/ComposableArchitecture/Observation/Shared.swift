import Foundation
import Perception

@dynamicMemberLookup
@Perceptible
public final class Shared<Value> {
  private var _value: Value
  private let lock = NSRecursiveLock()

  public var value: Value {
    get { self.lock.sync { self._value } }
    set { self.lock.sync { self._value = newValue } }
  }

  public init(_ value: Value) {
    self._value = value
  }
  
  public subscript<Member>(dynamicMember keyPath: WritableKeyPath<Value, Member>) -> Member {
    get { self.value[keyPath: keyPath] }
    set { self.value[keyPath: keyPath] = newValue }
  }
}

// TODO: Should these be conditional conformances?

extension Shared: Equatable {
  public static func == (lhs: Shared, rhs: Shared) -> Bool {
    lhs === rhs
  }
}

extension Shared: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
}

// TODO: Should this be conditional conformance?

extension Shared: Identifiable {
  public var id: ObjectIdentifier {
    ObjectIdentifier(self)
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
      try container.encode(self.value)
    } catch {
      try self.value.encode(to: encoder)
    }
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

extension DependencyValues {
  public subscript<Key: TestDependencyKey>(shared _: Key.Type) -> Key.Value {
    get { self[Shared<Key>.self].value }
    set { self[Shared<Key>.self] = Shared(newValue) }
  }
}

@propertyWrapper
public struct SharedDependency<Key: TestDependencyKey> where Key.Value == Key {
  private let dependency = Dependency(Shared<Key>.self)

  public var wrappedValue: Key.Value {
    get { dependency.wrappedValue.value }
    set { dependency.wrappedValue.value = newValue }
  }

  public var projectedValue: Shared<Key.Value> {
    dependency.wrappedValue
  }

  public init() {}
}

extension SharedDependency: Equatable where Key.Value: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.wrappedValue == rhs.wrappedValue
  }
}

extension SharedDependency: Hashable where Key.Value: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.wrappedValue)
  }
}

extension SharedDependency: CustomDumpReflectable {
  public var customDumpMirror: Mirror {
    Mirror(reflecting: self.wrappedValue)
  }
}
