public protocol DependencyKey {
  associatedtype Value
  static var testValue: Value { get }
}

public protocol LiveDependencyKey: DependencyKey {
  static var liveValue: Value { get }
}

public struct DependencyValues {
  @TaskLocal static var current = Self()

  private var storage: [ObjectIdentifier: Any] = [:]

  // TODO: lock storage?
  public subscript<Key>(key: Key.Type) -> Key.Value where Key: DependencyKey {
    get {
      guard let dependency = self.storage[ObjectIdentifier(key)] as? Key.Value
      else {
        func open<T>(_: T.Type) -> Any? {
          let isTesting = self.storage[ObjectIdentifier(IsTestingKey.self)] as? Bool
          // TODO: better way to detect tests running?
          ?? (ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil)
          guard !isTesting
          else { return nil }
          return (Witness<T>.self as? AnyLiveDependencyKey.Type)?.liveValue
        }

        return _openExistential(Key.self as Any.Type, do: open) as? Key.Value
        ?? Key.testValue
      }
      return dependency
    }
    set { self.storage[ObjectIdentifier(key)] = newValue }
  }
}

// TODO: Why is this needed?
#if compiler(<5.7)
  extension DependencyValues: @unchecked Sendable {}
#endif

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

@dynamicMemberLookup
public struct DependencyKeyWritingReducer<Upstream: ReducerProtocol, Value>: ReducerProtocol {
  @usableFromInline
  let upstream: Upstream

  @usableFromInline
  let update: (inout DependencyValues) -> Void

  @usableFromInline
  init(upstream: Upstream, update: @escaping (inout DependencyValues) -> Void) {
    self.upstream = upstream
    self.update = update
  }

  public func reduce(
    into state: inout Upstream.State, action: Upstream.Action
  ) -> Effect<Upstream.Action, Never> {
    var values = DependencyValues.current
    self.update(&values)
    return DependencyValues.$current.withValue(values) {
      self.upstream.reduce(into: &state, action: action)
    }
  }

  @inlinable
  public func dependency<Value>(
    _ keyPath: WritableKeyPath<DependencyValues, Value>,
    _ value: Value
  ) -> Self {
    .init(upstream: self.upstream) { values in
      self.update(&values)
      values[keyPath: keyPath] = value
    }
  }

  public subscript<Value>(dynamicMember keyPath: KeyPath<Upstream, Value>) -> Value {
    var values = DependencyValues.current
    self.update(&values)
    return DependencyValues.$current.withValue(values) {
      self.upstream[keyPath: keyPath]
    }
  }
}

extension ReducerProtocol {
  @inlinable
  public func dependency<Value>(
    _ keyPath: WritableKeyPath<DependencyValues, Value>,
    _ value: Value
  ) -> DependencyKeyWritingReducer<Self, Value> {
    .init(upstream: self) { $0[keyPath: keyPath] = value }
  }
}

extension DependencyValues {
  public var isTesting: Bool {
    _read { yield self[IsTestingKey.self] }
    _modify { yield &self[IsTestingKey.self] }
  }

  private enum IsTestingKey: LiveDependencyKey {
    static let liveValue = false
    static let testValue = true
  }
}

private enum Witness<T> {}

private protocol AnyLiveDependencyKey {
  static var liveValue: Any { get }
}

extension Witness: AnyLiveDependencyKey where T: LiveDependencyKey {
  static var liveValue: Any { T.liveValue }
}
