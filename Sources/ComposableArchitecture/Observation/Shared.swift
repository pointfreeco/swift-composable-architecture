import Perception

// TODO: Should we force Value: TestDependencyKey so that we don't get crashes and just
//       get runtime warnings/test failures?
// TODO: make unchecked sendable with a lock
// TODO: Other names: Shared, ObservableRef,
@dynamicMemberLookup
@Perceptible
public final class Shared<Value> {
  public var value: Value
  public init(_ value: Value) {
    self.value = value
  }
  public subscript<T>(dynamicMember keyPath: WritableKeyPath<Value, T>) -> T {
    get { self.value[keyPath: keyPath] }
    set { self.value[keyPath: keyPath] = newValue }
  }
  public func copy() -> Shared<Value> {
    Shared(self.value)
  }
}
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
// TODO: try reference identity
extension Shared: Identifiable where Value: Identifiable {
  public var id: Value.ID {
    self.value.id
  }
}
extension Shared: Codable where Value: Codable {
  public convenience init(from decoder: Decoder) throws {
    do {
      self.init(try decoder.singleValueContainer().decode(Value.self))
    } catch {
      self.init(try .init(from: decoder))
    }
  }
  public func encode(to encoder: Encoder) throws {
    do {
      var container = encoder.singleValueContainer()
      try container.encode(self.value)
    } catch {
      try self.value.encode(to: encoder)
    }
  }
}
