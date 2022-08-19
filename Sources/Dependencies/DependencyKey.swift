public protocol DependencyKey {
  associatedtype Value
  // NB: This associated type should be constrained to `Sendable` when this bug is fixed:
  //     https://github.com/apple/swift/issues/60649

  static var testValue: Value { get }
}

public protocol LiveDependencyKey: DependencyKey {
  static var liveValue: Value { get }
}
