/// A context for a collection of ``DependencyValues``.
///
/// There are three distinct contexts that dependencies can be loaded from and registered to:
///
/// * ``live``: The default context.
/// * ``preview``: A context for Xcode previews.
/// * ``test``: A context for tests.
public enum DependencyContext: Sendable {
  /// The default, "live" context for dependencies.
  ///
  /// This context is the default when a ``preview`` or ``test`` context is not detected.
  ///
  /// Dependencies accessed from a live context will use ``DependencyKey/liveValue`` to request a
  /// default value.
  case live

  /// A "preview" context for dependencies.
  ///
  /// This context is the default when run from an Xcode preview.
  ///
  /// Dependencies accessed from a preview context will use ``TestDependencyKey/previewValue-8u2sy``
  /// to request a default value.
  case preview

  /// A "test" context for dependencies.
  ///
  /// This context is the default when run from an XCTest run.
  ///
  /// Dependencies accessed from a test context will use ``TestDependencyKey/testValue`` to request
  /// a default value.
  case test
}
