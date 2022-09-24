import XCTestDynamicOverlay

/// A key for accessing dependencies.
///
/// Types conform to this protocol to extend ``DependencyValues`` with custom dependencies. It is
/// similar to SwiftUI's `EnvironmentKey` protocol, which is used to add values to
/// `EnvironmentValues`.
///
/// `DependencyKey` has one main requirement, ``liveValue``, which must return a default value for
/// your dependency that is used when the application is run in a simulator or device.
///
/// `DependencyKey` inherits two overridable requirements from ``TestDependencyKey``:
/// ``TestDependencyKey/testValue``, which should return a default value for the purpose of
/// testing, and ``TestDependencyKey/previewValue-8u2sy``, which can return a default value suitable
/// for Xcode previews. When left unimplemented, these endpoints will return the ``liveValue``,
/// instead.
///
/// If you plan on separating your interface from your live implementation, conform to
/// ``TestDependencyKey`` in your interface module, and extend this conformance to `DependencyKey`
/// in your implementation module.
///
///
public protocol DependencyKey: TestDependencyKey {
  /// The live value for the dependency key.
  static var liveValue: Value { get }

  // NB: The associated type and requirements of TestDependencyKey are repeated in this protocol
  //     due to a Swift compiler bug that prevents it from inferring the associated type in
  //     in the base protocol. See this issue for more information:
  //     https://github.com/apple/swift/issues/61077

  /// The associated type representing the type of the dependency key's value.
  associatedtype Value = Self

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

/// A key for accessing test dependencies.
///
/// This protocol lives one layer below ``DependencyKey`` and allows you to separate a dependency's
/// interface from its live implementation.
///
/// ``TestDependencyKey`` has one main requirement, ``testValue``, which must return a default value
/// for the purposes of testing, and one optional requirement, ``previewValue-8u2sy``, which can
/// return a default value suitable for Xcode previews, or the ``testValue``, if left unimplemented.
///
/// See ``DependencyKey`` to define a static, default value for the live application.
public protocol TestDependencyKey {
  /// The associated type representing the type of the dependency key's value.
  associatedtype Value = Self

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
  /// A default implementation that provides the ``liveValue`` to Xcode previews.
  public static var previewValue: Value { Self.liveValue }

  /// A default implementation that provides the ``liveValue`` to tests. A test failure will occur
  /// if the dependency is accessed in a test. To fix, override the dependency on the test store
  /// to use a mock or provide a `testValue` in your conformance to ``TestDependencyKey``.
  public static var testValue: Value {
    var dependencyDescription = ""
    if
      let fileID = DependencyValues.currentDependency.fileID,
      let line = DependencyValues.currentDependency.line
    {
      dependencyDescription.append(
        """
          Location:
            \(fileID):\(line)

        """
      )
    }
    dependencyDescription.append(
      Self.self == Value.self
        ? """
          Dependency:
            \(typeName(Value.self))
        """
        : """
          Key:
            \(typeName(Self.self))
          Value:
            \(typeName(Value.self))
        """
    )
    XCTFail(
      """
      \(DependencyValues.currentDependency.name.map { "@Dependency(\\.\($0))" } ?? "A dependency") \
      has no test implementation, but was accessed from a test context:

      \(dependencyDescription)

      Dependencies registered with the library are not allowed to use their live implementations \
      when run in a 'TestStore'.

      There are two ways to fix:

      • Make \(typeName(Self.self)) provide an implementation of 'testValue' in its conformance to \
      the 'DependencyKey' protocol.
      • Override \(DependencyValues.currentDependency.name.map { "'\($0)'" } ?? "the dependency") \
      with a mock in your test by mutating the 'dependencies' property on your 'TestStore'.
      """
    )
    return Self.previewValue
  }
}

extension TestDependencyKey {
  /// A default implementation that provides the ``testValue`` to Xcode previews.
  public static var previewValue: Value { Self.testValue }
}
