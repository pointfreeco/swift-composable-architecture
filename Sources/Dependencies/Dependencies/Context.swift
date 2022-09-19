extension DependencyValues {
  /// The current dependency context.
  public var context: DependencyContext {
    get { self[DependencyContextKey.self] }
    set { self[DependencyContextKey.self] = newValue }
  }
}

enum DependencyContextKey: DependencyKey {
  static var liveValue = DependencyContext.live
  static var previewValue = DependencyContext.preview
  static var testValue = DependencyContext.test
}
