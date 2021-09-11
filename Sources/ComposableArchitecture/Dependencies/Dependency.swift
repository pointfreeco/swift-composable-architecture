public protocol DependencyKey {
  associatedtype Value
  static var defaultValue: Value { get }
}

public class DependencyValues {
  @usableFromInline
  static var shared = DependencyValues()

  var storage: [ObjectIdentifier: Any] = [:]

  public subscript<Key: DependencyKey>(key: Key.Type) -> Key.Value {
    get {
      let id = ObjectIdentifier(key)
      guard let dependency = storage[id]
      else {
        let defaultValue = Key.defaultValue
        storage[id] = defaultValue
        return defaultValue
      }
      guard let value = dependency as? Key.Value
      else { fatalError() }
      return value
    }
    set {
      storage[ObjectIdentifier(key)] = newValue
    }
  }
}

@propertyWrapper
public struct Dependency<Value> {
  public let keyPath: WritableKeyPath<DependencyValues, Value>

  public init(_ keyPath: WritableKeyPath<DependencyValues, Value>) {
    self.keyPath = keyPath
  }

  public var wrappedValue: Value {
    get {
      DependencyValues.shared[keyPath: self.keyPath]
    }
  }
}
