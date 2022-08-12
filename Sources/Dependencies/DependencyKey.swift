public protocol DependencyKey {
  associatedtype Value: Sendable
  static var testValue: Value { get }
}

public protocol LiveDependencyKey: DependencyKey {
  static var liveValue: Value { get }
}
