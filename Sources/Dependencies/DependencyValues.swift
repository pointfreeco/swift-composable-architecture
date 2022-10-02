import Foundation
import XCTestDynamicOverlay

// TODO: should we have `@Dependency(\.runtimeWarningsEnabled)` and/or `@Dependency(\.treatWarningsAsErrors)`?

/// A collection of dependencies propagated through a reducer hierarchy.
///
/// The Composable Architecture exposes a collection of values to your app's reducers in an
/// ``DependencyValues`` structure. This is similar to the `EnvironmentValues` structure SwiftUI
/// exposes to views.
///
/// To register a dependency with this storage, you first conform a type to ``DependencyKey``:
///
/// ```swift
/// private enum MyValueKey: DependencyKey {
///   static let liveValue = 42
/// }
/// ```
///
/// And then extend ``DependencyValues`` with a computed property that uses the key to read and
/// write to ``DependencyValues``:
///
/// ```swift
/// extension DependencyValues {
///   get { self[MyValueKey.self] }
///   set { self[MyValueKey.self] = newValue }
/// }
/// ```
///
/// To access a dependency from ``DependencyValues`` you declare a variable using the ``Dependency``
/// property wrapper:
///
/// ```swift
/// @Dependency(\.myValue) var myValue
/// myValue // 42
/// ```
public struct DependencyValues: Sendable {
  @TaskLocal public static var _current = Self()

  @TaskLocal static var isSetting = false
  @TaskLocal static var currentDependency = CurrentDependency()

  /// Binds the task-local dependencies to the updated value for the duration of the synchronous
  /// operation.
  ///
  /// - Parameters:
  ///   - updateForOperation: A closure for updating the current dependency values for the duration
  ///     of the operation.
  ///   - operation: An operation to perform wherein dependencies have been overridden.
  /// - Returns: The result returned from `operation`.
  public static func withValues<R>(
    _ updateValuesForOperation: (inout Self) throws -> Void,
    operation: () throws -> R,
    file: String = #fileID,
    line: UInt = #line
  ) rethrows -> R {
    try Self.$isSetting.withValue(true) {
      var dependencies = Self._current
      try updateValuesForOperation(&dependencies)
      return try Self.$_current.withValue(dependencies) {
        try operation()
      }
    }
  }

  /// Binds the task-local dependencies to the updated value for the duration of the asynchronous
  /// operation.
  ///
  /// - Parameters:
  ///   - updateForOperation: A closure for updating the current dependency values for the duration
  ///     of the operation.
  ///   - operation: An operation to perform wherein dependencies have been overridden.
  /// - Returns: The result returned from `operation`.
  public static func withValues<R>(
    _ updateValuesForOperation: (inout Self) async throws -> Void,
    operation: () async throws -> R,
    file: String = #fileID,
    line: UInt = #line
  ) async rethrows -> R {
    try await Self.$isSetting.withValue(true) {
      var dependencies = Self._current
      try await updateValuesForOperation(&dependencies)
      return try await Self.$_current.withValue(dependencies) {
        try await operation()
      }
    }
  }

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
    function: StaticString = #function,
    line: UInt = #line
  ) -> Key.Value where Key.Value: Sendable {
    get {
      guard let dependency = self.storage[ObjectIdentifier(key)]?.base as? Key.Value
      else {
        let context =
          self.storage[ObjectIdentifier(DependencyContextKey.self)]?.base as? DependencyContext
          ?? defaultContext

        switch context {
        case .live:
          guard let value = _liveValue(Key.self) as? Key.Value
          else {
            if !Self.isSetting {
              var dependencyDescription = ""
              if
                let fileID = Self.currentDependency.fileID,
                let line = Self.currentDependency.line
              {
                dependencyDescription.append(
                  """
                    Location:
                      \(fileID):\(line)

                  """
                )
              }
              dependencyDescription.append(
                Key.self == Key.Value.self
                  ? """
                    Dependency:
                      \(typeName(Key.Value.self))
                  """
                  : """
                    Key:
                      \(typeName(Key.self))
                    Value:
                      \(typeName(Key.Value.self))
                  """
              )

              runtimeWarning(
                """
                @Dependency(\\.%@) has no live implementation, but was accessed from a live context.

                %@

                Every dependency registered with the library must conform to 'DependencyKey', and \
                that conformance must be visible to the running application.

                To fix, make sure that '%@' conforms to 'DependencyKey' by providing a live \
                implementation of your dependency, and make sure that the conformance is linked \
                with this current application.
                """,
                [
                  "\(function)",
                  dependencyDescription,
                  typeName(Key.self),
                ],
                file: Self.currentDependency.file ?? file,
                line: Self.currentDependency.line ?? line
              )
            }
            return Key.testValue
          }
          return value
        case .preview:
          return Key.previewValue
        case .test:
          var currentDependency = Self.currentDependency
          currentDependency.name = function
          return Self.$currentDependency.withValue(currentDependency) {
            Key.testValue
          }
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

struct CurrentDependency {
  var name: StaticString?
  var file: StaticString?
  var fileID: StaticString?
  var line: UInt?
}

private let defaultContext: DependencyContext = {
  if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
    return .preview
  } else if _XCTIsTesting {
    return .test
  } else {
    return .live
  }
}()
