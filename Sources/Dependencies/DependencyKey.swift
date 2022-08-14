public protocol DependencyKey {
  #if swift(>=5.7)
    associatedtype Value: Sendable
  #else
    associatedtype Value
  #endif
  static var testValue: Value { get }
}

public protocol LiveDependencyKey: DependencyKey {
  static var liveValue: Value { get }
}
