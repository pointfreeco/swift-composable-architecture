// TODO: other names? DependencyStubKey, DependencyTestKey,
public protocol DependencyStub {
  // TODO: Should Value be Dependency?
  associatedtype Value
  static var testValue: Value { get }

  // TODO: Should this also have a previewValue? noopValue?
}

public protocol DependencyKey: DependencyStub {
  // TODO: liveValue?
  static var defaultValue: Value { get }
}

// TODO: Rename to Dependencies?
public class DependencyValues {
  @usableFromInline
  static var shared = DependencyValues()

  var storage: [[ObjectIdentifier: Any]] = [[:]]

  @usableFromInline
  func push() {
    self.storage.append(self.storage.last!)
  }

  @usableFromInline
  func pop() {
    self.storage.removeLast()
  }

  public subscript<Key: DependencyStub>(key: Key.Type) -> Key.Value {
    get {
      let id = ObjectIdentifier(key)
      guard let dependency = self.storage.last?[id]
      else {
        func open<T>(_: T.Type) -> Any? {
          let isTesting = self.storage.last?[ObjectIdentifier(IsTestingKey.self)] as? Bool ?? false
          guard !isTesting
          else { return nil }

          return (Box<T>.self as? AnyDependencyKey.Type)?.defaultValue()
        }

        let dependency = _openExistential(Key.self as Any.Type, do: open) as? Key.Value
        ?? Key.testValue
        self.storage[self.storage.count - 1][id] = dependency
        return dependency
      }
      guard let value = dependency as? Key.Value
      else { fatalError() }
      return value
    }
    set {
      self.storage[self.storage.count - 1][ObjectIdentifier(key)] = newValue
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

enum Box<T> {}

protocol AnyDependencyKey {
  static func defaultValue() -> Any
}

extension Box: AnyDependencyKey where T: DependencyKey {
  static func defaultValue() -> Any {
    T.defaultValue
  }
}

private enum IsTestingKey: DependencyKey {
  static let defaultValue = false
  static let testValue = true
}
extension DependencyValues {
  var isTesting: Bool {
    get { self[IsTestingKey.self] }
    set { self[IsTestingKey.self] = newValue }
  }
}
