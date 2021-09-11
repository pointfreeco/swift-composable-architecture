import Foundation
import CombineSchedulers

// MARK: - DependencyKey
protocol DependencyKey {
  associatedtype Value
  static var defaultValue: Value { get }
}

enum MainQueueKey: DependencyKey {
  static var defaultValue = AnySchedulerOf<DispatchQueue>.main
}
extension DependencyValues {
  var mainQueue: AnySchedulerOf<DispatchQueue> {
    get { self[MainQueueKey.self] }
    set { self[MainQueueKey.self] = newValue }
  }
}

class DependencyValues {
  var storage: [ObjectIdentifier: Any] = [:]
  static var shared = DependencyValues()

  subscript<Key: DependencyKey>(key: Key.Type) -> Key.Value {
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

struct DependencyKeyWritingReducer<Upstream, Value>: _Reducer
where
Upstream: _Reducer
{
  let upstream: Upstream
  let keyPath: WritableKeyPath<DependencyValues, Value>
  let value: Value

  func reduce(into state: inout Upstream.State, action: Upstream.Action) -> Effect<Upstream.Action, Never> {
    // TODO: push and pop dependency context
    DependencyValues.shared[keyPath: self.keyPath] = value
    return self.upstream.reduce(into: &state, action: action)
  }
}

extension _Reducer {
  func dependency<Value>(
    _ keyPath: WritableKeyPath<DependencyValues, Value>,
    _ value: Value
  ) -> DependencyKeyWritingReducer<Self, Value> {
    .init(upstream: self, keyPath: keyPath, value: value)
  }
}

@propertyWrapper
struct Dependency<Value> {
  let keyPath: WritableKeyPath<DependencyValues, Value>

  init(_ keyPath: WritableKeyPath<DependencyValues, Value>) {
    self.keyPath = keyPath
  }

  var wrappedValue: Value {
    get {
      DependencyValues.shared[keyPath: self.keyPath]
    }
  }
}
