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
  // TODO: rename `Context`
  public enum Environment: Sendable {
    case live
    case preview
    case test
  }

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
  public subscript<Key: DependencyKey>(
    key: Key.Type,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> Key.Value where Key.Value: Sendable {
    get {
      guard let dependency = self.storage[ObjectIdentifier(key)]?.base as? Key.Value
      else {
        let mode =
          self.storage[ObjectIdentifier(EnvironmentKey.self)]?.base as? Environment
          ?? (isPreview ? .preview : .live)

        switch mode {
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

              Every dependency registered with the library must conform to 'LiveDependencyKey', \
              and that conformance must be visible to the running application.

              To fix, make sure that '%3$@' conforms to 'LiveDependencyKey' by providing a live \
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

extension DependencyValues {
  public var isTesting: Bool {
    _read { yield self[IsTestingKey.self] }
    _modify { yield &self[IsTestingKey.self] }
  }

  private enum IsTestingKey: LiveDependencyKey {
    static let liveValue = false
    static var previewValue = false
    static let testValue = true
  }
}

private struct AnySendable: @unchecked Sendable {
  let base: Any

  init<Base: Sendable>(_ base: Base) {
    self.base = base
  }
}

private enum EnvironmentKey: LiveDependencyKey {
  static var liveValue = DependencyValues.Environment.live
  static var previewValue = DependencyValues.Environment.preview
  static var testValue = DependencyValues.Environment.test
}

extension DependencyValues {
  // TODO: Should we reconsider this name?
  // Using and mentioning our own "dependency environment" and also mentioning SwiftUI's environment
  // in the same documentation is confusing, so maybe we can come up with something more unique. We
  // discussed "mode," but do we like `.dependency(\.mode, .test)`? Can we come up with better?
  public var environment: DependencyValues.Environment {
    get { self[EnvironmentKey.self] }
    set { self[EnvironmentKey.self] = newValue }
  }
}

#if DEBUG
  private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
#else
  private let isPreview = false
#endif
