/// A context for a collection of ``DependencyValues``.
public enum DependencyContext: Sendable {
  /// A "live" set of dependencies.
  ///
  /// This context is the default for live stores.
  case live

  /// A "preview" set of dependencies.
  ///
  /// This context is the default for stores running in Xcode previews.
  case preview

  /// A "test" set of dependencies.
  ///
  /// This context is the default for test stores.
  case test
}
