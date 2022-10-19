import XCTestDynamicOverlay

/// A key for accessing dependencies.
///
/// Types conform to this protocol to extend ``DependencyValues`` with custom dependencies. It is
/// similar to SwiftUI's `EnvironmentKey` protocol, which is used to add values to
/// `EnvironmentValues`.
///
/// `DependencyKey` has one main requirement, ``liveValue``, which must return a default value for
/// your dependency that is used when the application is run in a simulator or device. If the
/// ``liveValue`` is accessed while your feature runs in a `TestStore` a test failure will be
/// triggered.
///
/// To add a `UserClient` dependency that can fetch and save user values can be done like so:
///
/// ```swift
/// // The user client dependency.
/// struct UserClient {
///   var fetchUser: (User.ID) async throws -> User
///   var saveUser: (User) async throws -> Void
/// }
/// // Conform to DependencyKey to provide a live implementation of
/// // the interface.
/// extension UserClient: DependencyKey {
///   static let liveValue = Self(
///     fetchUser: { /* Make request to fetch user */ },
///     saveUser: { /* Make request to save user */ }
///   )
/// }
/// // Register the dependency within DependencyValues.
/// extension DependencyValues {
///   var userClient: UserClient {
///     get { self[UserClient.self] }
///     set { self[UserClient.self] = newValue }
///   }
/// }
/// ```
///
/// When a dependency is first accessed its value is cached so that it will not be requested again.
/// This means if your `liveValue` is implemented as a computed property instead of a `static let`,
/// then it will only be called a single time:
///
/// ```swift
/// extension UserClient: DependencyKey {
///   static var liveValue: Self {
///     // Only called once when dependency is first accessed.
///     return Self(…)
///   }
/// }
/// ```
///
/// `DependencyKey` inherits from ``TestDependencyKey``, which has two other overridable
/// requirements: ``TestDependencyKey/testValue``, which should return a default value for the
/// purpose of testing, and ``TestDependencyKey/previewValue-8u2sy``, which can return a default
/// value suitable for Xcode previews. When left unimplemented, these endpoints will return the
/// ``liveValue``, instead.
///
/// If you plan on separating your interface from your live implementation, conform to
/// ``TestDependencyKey`` in your interface module, and conform to `DependencyKey` in your
/// implementation module.
public protocol DependencyKey: TestDependencyKey {
  /// The live value for the dependency key.
  ///
  /// This is the value used by default when running the application in a simulator or on a device.
  /// Using a live dependency in a test context will lead to a test failure as you should mock
  /// your dependencies for tests.
  ///
  /// To automatically supply a test dependency in a test context, consider implementing the
  /// ``testValue-535kh`` requirement.
  static var liveValue: Value { get }

  // NB: The associated type and requirements of TestDependencyKey are repeated in this protocol
  //     due to a Swift compiler bug that prevents it from inferring the associated type in
  //     in the base protocol. See this issue for more information:
  //     https://github.com/apple/swift/issues/61077

  /// The associated type representing the type of the dependency key's value.
  associatedtype Value = Self

  /// The preview value for the dependency key.
  ///
  /// This value is automatically used when the associated dependency value is accessed from an
  /// Xcode preview, as well as when the current ``DependencyValues/context`` is set to
  /// ``DependencyContext/preview``:
  ///
  /// ```swift
  /// DependencyValues.withValues {
  ///   $0.context = .preview
  /// } operation: {
  ///   // Dependencies accessed here default to their "preview" value
  /// }
  /// ```
  static var previewValue: Value { get }

  /// The test value for the dependency key.
  ///
  /// This value is automatically used when the associated dependency value is accessed from an
  /// XCTest run, as well as when the current ``DependencyValues/context`` is set to
  /// ``DependencyContext/test``:
  ///
  /// ```swift
  /// DependencyValues.withValues {
  ///   $0.context = .test
  /// } operation: {
  ///   // Dependencies accessed here default to their "test" value
  /// }
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
  /// This value is automatically used when the associated dependency value is accessed from an
  /// Xcode preview, as well as when the current ``DependencyValues/context`` is set to
  /// ``DependencyContext/preview``:
  ///
  /// ```swift
  /// DependencyValues.withValues {
  ///   $0.context = .preview
  /// } operation: {
  ///   // Dependencies accessed here default to their "preview" value
  /// }
  /// ```
  static var previewValue: Value { get }

  /// The test value for the dependency key.
  ///
  /// This value is automatically used when the associated dependency value is accessed from an
  /// XCTest run, as well as when the current ``DependencyValues/context`` is set to
  /// ``DependencyContext/test``:
  ///
  /// ```swift
  /// DependencyValues.withValues {
  ///   $0.context = .test
  /// } operation: {
  ///   // Dependencies accessed here default to their "test" value
  /// }
  /// ```
  static var testValue: Value { get }
}

extension DependencyKey {
  /// A default implementation that provides the ``liveValue`` to Xcode previews.
  ///
  /// You may provide your own default `previewValue` in your conformance to ``TestDependencyKey``,
  /// which will take precedence over this implementation.
  public static var previewValue: Value { Self.liveValue }

  /// A default implementation that provides the ``liveValue`` to XCTest runs, but will trigger test
  /// failure to occur if accessed.
  ///
  /// To prevent test failures, explicitly override the dependency in any tests in which it is
  /// accessed:
  ///
  /// ```swift
  /// func testFeatureThatUsesMyDependency() {
  ///   DependencyValues.withValues {
  ///     $0.myDependency = .mock // Override dependency
  ///   } operation: {
  ///     // Test feature with dependency overridden
  ///   }
  /// }
  /// ```
  ///
  /// You may provide your own default `testValue` in your conformance to ``TestDependencyKey``,
  /// which will take precedence over this implementation.
  public static var testValue: Value {
    var dependencyDescription = ""
    if let fileID = DependencyValues.currentDependency.fileID,
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
    // TODO: Make this error message configurable to avoid TCA-specific language outside of TCA?
    XCTFail(
      """
      \(DependencyValues.currentDependency.name.map { "@Dependency(\\.\($0))" } ?? "A dependency") \
      has no test implementation, but was accessed from a test context:

      \(dependencyDescription)

      Dependencies registered with the library are not allowed to use their default, live \
      implementations when run from tests.

      To fix, override \
      \(DependencyValues.currentDependency.name.map { "'\($0)'" } ?? "the dependency") with a mock \
      value in your test. If you are using the Composable Architecture, mutate the 'dependencies' \
      property on your 'TestStore'. Otherwise, use 'DependencyValues.withValues' to define a scope \
      for the override. If you'd like to provide a default value for all tests, implement the \
      'testValue' requirement of the 'DependencyKey' protocol.
      """
    )
    return Self.liveValue
  }
}

extension TestDependencyKey {
  /// A default implementation that provides the ``testValue`` to Xcode previews.
  ///
  /// You may provide your own default `previewValue` in your conformance to ``TestDependencyKey``,
  /// which will take precedence over this implementation.
  public static var previewValue: Value { Self.testValue }
}
