@propertyWrapper
public struct Dependency<Value> {
  public let keyPath: KeyPath<DependencyValues, Value>

  public init(_ keyPath: KeyPath<DependencyValues, Value>) {
    self.keyPath = keyPath
  }

  public var wrappedValue: Value {
    DependencyValues.current[keyPath: self.keyPath]
  }

  public static func with<Result>(
    _ keyPath: WritableKeyPath<DependencyValues, Value>,
    _ value: Value,
    operation: () throws -> Result
  ) rethrows -> Result {
    var values = DependencyValues.current
    values[keyPath: keyPath] = value
    return try DependencyValues.$current.withValue(values, operation: operation)
  }

  public static func with<Result>(
    _ keyPath: WritableKeyPath<DependencyValues, Value>,
    _ value: Value,
    operation: () async throws -> Result
  ) async rethrows -> Result {
    var values = DependencyValues.current
    values[keyPath: keyPath] = value
    return try await DependencyValues.$current.withValue(values, operation: operation)
  }
}

extension Dependency: @unchecked Sendable where Value: Sendable {}
