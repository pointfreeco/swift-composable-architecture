extension DependencyValues {
  /// The current dependency context.
  ///
  /// The current ``DependencyContext`` can be used to determine how dependencies are loaded by the
  /// current runtime.
  ///
  /// It can also be overridden, for example via ``withValue(_:_:operation:)-705n``, to control how
  /// dependencies will be loaded by the runtime for the duration of the override.
  ///
  /// ```swift
  /// DependencyValues.withValue(\.context, .preview) {
  ///   // Dependencies accessed here default to their "preview" value
  /// }
  /// ```
  public var context: DependencyContext {
    get { self[DependencyContextKey.self] }
    set { self[DependencyContextKey.self] = newValue }
  }
}

enum DependencyContextKey: DependencyKey {
  static let liveValue = DependencyContext.live
  static let previewValue = DependencyContext.preview
  static let testValue = DependencyContext.test
}
