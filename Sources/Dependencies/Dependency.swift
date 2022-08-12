/// A property wrapper that exposes dependencies to reducers.
///
/// Similar to SwiftUI's `Environment` property wrapper, which provides dependencies to views, the
/// `Dependency` property wrapper provides dependencies to reducers.
///
/// For the complete list of dependency values provided by the Composable Architecture, see the
/// properties of the ``DependencyValues`` structure. For information about creating custom
/// dependency values, see the ``DependencyKey`` protocol.
@propertyWrapper
public struct Dependency<Value> {
  public let keyPath: KeyPath<DependencyValues, Value>

  public init(_ keyPath: KeyPath<DependencyValues, Value>) {
    self.keyPath = keyPath
  }

  public var wrappedValue: Value {
    DependencyValues.current[keyPath: self.keyPath]
  }
}

extension Dependency: @unchecked Sendable where Value: Sendable {}
