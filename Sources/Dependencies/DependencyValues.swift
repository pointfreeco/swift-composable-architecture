/// A collection of dependencies propagated through a reducer hierarchy.
///
/// The Composable Architecture exposes a collection of values to your app's reducers in an
/// ``DependencyValues`` structure. This is similar to the `EnvironmentValues` structure SwiftUI
/// exposes to views.
///
/// To read a value from the structure, declare a property using the ``Dependency`` property wrapper
/// and specify the value's key path. For example, you can read the current date:
///
/// ```swift
/// @Dependency(\.date) var date
/// ```
public struct DependencyValues: Sendable {
  @TaskLocal public static var current = Self()

  private var storage: [ObjectIdentifier: AnySendable] = [:]

  public init() {}

  public init(isTesting: Bool) {
    self.isTesting = isTesting
  }

  public subscript<Key: DependencyKey>(key: Key.Type) -> Key.Value {
    get {
      guard let dependency = self.storage[ObjectIdentifier(key)]?.base as? Key.Value
      else {
        let isTesting = self.storage[ObjectIdentifier(IsTestingKey.self)]?.base as? Bool ?? false
        guard !isTesting else { return Key.testValue }
        return _liveValue(Key.self) as? Key.Value ?? Key.testValue
      }
      return dependency
    }
    set {
      self.storage[ObjectIdentifier(key)] = AnySendable(newValue)
    }
  }
}

// TODO: Why is this needed?
#if compiler(<5.7)
  extension DependencyValues: @unchecked Sendable {}
#endif

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

private struct AnySendable: @unchecked Sendable {
  let base: Any
  
  init(_ base: some Sendable) {
    self.base = base
  }
}
