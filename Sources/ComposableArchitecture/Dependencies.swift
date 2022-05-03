public protocol DependencyKey {
  associatedtype Value
  static var testValue: Value { get }
}

public protocol LiveDependencyKey: DependencyKey {
  static var liveValue: Value { get }
}

public struct DependencyValues {
  @TaskLocal public static var current = Self()

  private var storage: [ObjectIdentifier: Any] = [:]

  public subscript<Key>(key: Key.Type) -> Key.Value where Key: DependencyKey {
    get {
      guard let dependency = self.storage[ObjectIdentifier(key)] as? Key.Value
      else {
        func open<T>(_: T.Type) -> Any? {
          let isTesting = self.storage[ObjectIdentifier(IsTestingKey.self)] as? Bool ?? false
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

@propertyWrapper
public struct Dependency<Value> {
  public let keyPath: WritableKeyPath<DependencyValues, Value>

  public init(_ keyPath: WritableKeyPath<DependencyValues, Value>) {
    self.keyPath = keyPath
  }

  public var wrappedValue: Value {
    DependencyValues.current[keyPath: self.keyPath]
  }
}

public struct DependencyKeyWritingReducer<R: ReducerProtocol, Value>: ReducerProtocol {
  let upstream: R
  let keyPath: WritableKeyPath<DependencyValues, Value>
  let value: Value

  public func reduce(into state: inout R.State, action: R.Action) -> Effect<R.Action, Never> {
    var values = DependencyValues.current
    values[keyPath: self.keyPath] = self.value
    return DependencyValues.$current.withValue(values) {
      self.upstream.reduce(into: &state, action: action)
    }
  }
}

extension ReducerProtocol {
  public func dependency<Value>(
    _ keyPath: WritableKeyPath<DependencyValues, Value>,
    _ value: Value
  ) -> DependencyKeyWritingReducer<Self, Value> {
    .init(upstream: self, keyPath: keyPath, value: value)
  }
}

private enum Witness<T> {}

private protocol AnyLiveDependencyKey {
  static var liveValue: Any { get }
}

extension Witness: AnyLiveDependencyKey where T: LiveDependencyKey {
  static var liveValue: Any { T.liveValue }
}

private enum IsTestingKey: LiveDependencyKey {
  static let liveValue = false
  static let testValue = true
}

extension DependencyValues {
  public var isTesting: Bool {
    get { self[IsTestingKey.self] }
    set { self[IsTestingKey.self] = newValue }
  }
}
