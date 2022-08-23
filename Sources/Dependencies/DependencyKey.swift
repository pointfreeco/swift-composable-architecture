/// A key for accessing dependencies.
///
/// Similar to SwiftUI's `EnvironmentKey` protocol, which is used to extend `EnvironmentValues` with
/// custom dependencies, `DependencyKey` can be used to extend ``DependencyValues``.
///
/// `DependencyKey` has one main requirement, ``testValue``, which must return a default value for
/// the purposes of testing, and one optional requirement, ``previewValue``, which can return a
/// default value suitable for Xcode previews.
///
/// See ``LiveDependencyKey`` to define a static, default value for the live application.
///
/// TODO: rename to TestDependencyKey
public protocol DependencyKey {
  /// The associated type representing the type of the dependency key's value.
  associatedtype Value
  // NB: This associated type should be constrained to `Sendable` when this bug is fixed:
  //     https://github.com/apple/swift/issues/60649

  /// The preview value for the dependency key.
  ///
  /// This value is automatically installed into stores running in Xcode previews, as well as
  /// reducer hierarchies that set their dependency environment to `preview`:
  ///
  /// ```swift
  /// MyFeature()
  ///   .dependency(\.environment, .preview)
  /// ```
  static var previewValue: Value { get }

  /// The test value for the dependency key.
  ///
  /// This value is automatically installed into test stores and reducer hierarchies that set their
  /// dependency environment to `test`:
  ///
  /// ```swift
  /// MyFeature()
  ///   .dependency(\.environment, .test)
  /// ```
  static var testValue: Value { get }
}

extension DependencyKey {
  public static var previewValue: Value { Self.testValue }
}

/// A key for accessing live dependencies.
///
/// TODO: rename DependencyKey
public protocol LiveDependencyKey: DependencyKey {
  static var liveValue: Value { get }
}
