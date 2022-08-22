public protocol DependencyKey {
  associatedtype Value
  // NB: This associated type should be constrained to `Sendable` when this bug is fixed:
  //     https://github.com/apple/swift/issues/60649

  static var previewValue: Value { get }
  static var testValue: Value { get }
}

extension DependencyKey {
  public static var previewValue: Value { Self.testValue }
}

public protocol LiveDependencyKey: DependencyKey {
  static var liveValue: Value { get }
}
