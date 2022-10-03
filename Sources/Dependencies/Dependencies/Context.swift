extension DependencyValues {
  /// The current dependency context.
  ///
  /// The current ``DependencyContext`` can be used to determine how dependencies are loaded by the
  /// current runtime.
  ///
  /// It can also be overridden, for example via
  /// ``DependencyValues/withValues(_:operation:file:line:)-2atnb``, to control how dependencies
  /// will be loaded by the runtime for the duration of the override.
  ///
  /// ```swift
  /// DependencyValues.withValues {
  ///   $0.context = .preview
  /// } operation: {
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
