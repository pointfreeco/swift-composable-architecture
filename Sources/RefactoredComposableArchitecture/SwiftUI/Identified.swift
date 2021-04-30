/// A wrapper around a value and a hashable identifier that conforms to identifiable.
@dynamicMemberLookup
public struct Identified<ID, Value>: Identifiable where ID: Hashable {
  public let id: ID
  public var value: Value

  /// Initializes an identified value from a given value and a hashable identifier.
  ///
  /// - Parameters:
  ///   - value: A value.
  ///   - id: A hashable identifier.
  public init(_ value: Value, id: ID) {
    self.id = id
    self.value = value
  }

  /// Initializes an identified value from a given value and a function that can return a hashable
  /// identifier from the value.
  ///
  ///     Identified(uuid, id: \.self)
  ///
  /// - Parameters:
  ///   - value: A value.
  ///   - id: A hashable identifier.
  public init(_ value: Value, id: (Value) -> ID) {
    self.init(value, id: id(value))
  }

  // NB: This overload works around a bug in key path function expressions and `\.self`.
  /// Initializes an identified value from a given value and a function that can return a hashable
  /// identifier from the value.
  ///
  ///     Identified(uuid, id: \.self)
  ///
  /// - Parameters:
  ///   - value: A value.
  ///   - id: A key path from the value to a hashable identifier.
  public init(_ value: Value, id: KeyPath<Value, ID>) {
    self.init(value, id: value[keyPath: id])
  }

  public subscript<LocalValue>(
    dynamicMember keyPath: WritableKeyPath<Value, LocalValue>
  ) -> LocalValue {
    get { self.value[keyPath: keyPath] }
    set { self.value[keyPath: keyPath] = newValue }
  }
}

extension Identified: Decodable where ID: Decodable, Value: Decodable {}

extension Identified: Encodable where ID: Encodable, Value: Encodable {}

extension Identified: Equatable where Value: Equatable {}

extension Identified: Hashable where Value: Hashable {}
