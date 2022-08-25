import Foundation

// TODO: should we have `@Dependency(\.runtimeWarningsEnabled)` and/or `@Dependency(\.treatWarningsAsErrors)`?

/// A collection of dependencies propagated through a reducer hierarchy.
///
/// The Composable Architecture exposes a collection of values to your app's reducers in an
/// ``DependencyValues`` structure. This is similar to the `EnvironmentValues` structure SwiftUI
/// exposes to views.
///
/// To read a value from the structure, declare a property using the ``Dependency`` property wrapper
/// and specify the value's key path. For example, you can read the current date:
///
/// ```swift
/// @Dependency(\.date) var date
/// ```
public struct DependencyValues: Sendable {
  /// The current task's dependencies.
  ///
  /// You don't typically access dependencies directly, and instead will use the ``Dependency``
  /// property from your reducer conformance.
  ///
  /// This task local value provides a means of performing a scoped operation with certain
  /// dependency values overridden.
  @TaskLocal public static var current = Self()

  private var storage: [ObjectIdentifier: AnySendable] = [:]

  /// Creates a dependency values instance.
  ///
  /// You don't typically create an instance of ``DependencyValues`` directly. Doing so would
  /// provide access only to default values. Instead, you rely on an dependency values' instance
  /// that the Composable Architecture manages for you when you use the ``Dependency`` property
  /// wrapper and the `ReducerProtocol/dependency(_:_:)`` modifier.
  public init() {}

  /// Accesses the dependency value associated with a custom key.
  ///
  /// Create custom dependency values by defining a key that conforms to the ``DependencyKey``
  /// protocol, and then using that key with the subscript operator of the ``DependencyValues``
  /// structure to get and set a value for that key:
  ///
  /// ```swift
  /// private struct MyDependencyKey: DependencyKey {
  ///   static let testValue = "Default value"
  /// }
  ///
  /// extension DependencyValues {
  ///   var myCustomValue: String {
  ///     get { self[MyDependencyKey.self] }
  ///     set { self[MyDependencyKey.self] = newValue }
  ///   }
  /// }
  /// ```
  ///
  /// You use custom dependency values the same way you use system-provided values, setting a value
  /// with the `ReducerProtocol/dependency(_:_:)` modifier, and reading values with the
  /// ``Dependency`` property wrapper.
  public subscript<Key: TestDependencyKey>(
    key: Key.Type,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> Key.Value where Key.Value: Sendable {
    get {
      guard let dependency = self.storage[ObjectIdentifier(key)]?.base as? Key.Value
      else {
        let context =
          self.storage[ObjectIdentifier(DependencyContextKey.self)]?.base as? DependencyContext
          ?? (isPreview ? .preview : .live)

        switch context {
        case .live:
          guard let value = _liveValue(Key.self) as? Key.Value
          else {
            runtimeWarning(
              """
              A dependency at %@:%d is being used in a live environment without providing a live \
              implementation:

                Key:
                  %3$@
                Dependency:
                  %4$@

              Every dependency registered with the library must conform to 'DependencyKey', \
              and that conformance must be visible to the running application.

              To fix, make sure that '%3$@' conforms to 'DependencyKey' by providing a live \
              implementation of your dependency, and make sure that the conformance is linked \
              with this current application.
              """,
              [
                "\(fileID)",
                line,
                typeName(Key.self),
                typeName(Key.Value.self),
                typeName(Key.self),
              ],
              file: file,
              line: line
            )
            return Key.testValue
          }
          return value
        case .preview:
          return Key.previewValue
        case .test:
          return Key.testValue
        }
      }
      return dependency
    }
    set {
      self.storage[ObjectIdentifier(key)] = AnySendable(newValue)
    }
  }
}

private struct AnySendable: @unchecked Sendable {
  let base: Any

  init<Base: Sendable>(_ base: Base) {
    self.base = base
  }
}

#if DEBUG
  private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
#else
  private let isPreview = false
#endif
