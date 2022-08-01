public protocol DependencyKey {
  associatedtype Value
  static var testValue: Value { get }
}

public protocol LiveDependencyKey: DependencyKey {
  static var liveValue: Value { get }
}
