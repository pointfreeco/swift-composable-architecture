import Foundation
import XCTestDynamicOverlay

/// A collection of dependencies that is globally available.
///
/// To access a particular dependency from the collection you use the ``Dependency`` property
/// wrapper:
///
/// ```swift
/// @Dependency(\.date) var date
/// let now = date.now
/// ```
///
/// To change a dependency for a well-defined scope you can use the
/// ``withValues(_:operation:file:line:)-2atnb`` method:
///
/// ```swift
/// @Dependency(\.date) var date
/// let now = date.now
///
/// DependencyValues.withValues {
///   $0.date = .constant(Date(timeIntervalSinceReferenceDate: 1234567890))
/// } operation: {
///   @Dependency(\.date) var date
///   let now = date.now.timeIntervalSinceReferenceDate // 1234567890
/// }
/// ```
///
/// The dependencies will be changed only for the lifetime of the `operation` scope, which can be
/// synchronous or asynchronous.
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
/// With those steps done you can access the dependency using the ``Dependency`` property wrapper:
///
/// ```swift
/// @Dependency(\.myValue) var myValue
/// myValue // 42
/// ```
public struct DependencyValues: Sendable {
  @TaskLocal public static var _current = Self()

  @TaskLocal static var isSetting = false
  @TaskLocal static var currentDependency = CurrentDependency()

  /// Updates a single dependency for the duration of a synchronous operation.
  ///
  /// For example, if you wanted to force the ``DependencyValues/date`` dependency to be a
  /// particular date, you can do:
  ///
  /// ```swift
  /// DependencyValues.withValue(\.date, .constant(Date(timeIntervalSince1970: 1234567890))) {
  ///   // References to date in here are pinned to 1234567890.
  /// }
  /// ```
  ///
  /// See ``withValues(_:operation:)-9prz8`` to update multiple dependencies at once without nesting
  /// calls to `withValue`.
  ///
  /// - Parameters:
  ///   - keyPath: A key path that indicates the property of the `DependencyValues` structure to
  ///     update.
  ///   - value: The new value to set for the item specified by `keyPath`.
  ///   - operation: The operation to run with the updated dependencies.
  /// - Returns: The result returned from `operation`.
  public static func withValue<Value, R>(
    _ keyPath: WritableKeyPath<DependencyValues, Value>,
    _ value: Value,
    operation: () throws -> R
  ) rethrows -> R {
    try Self.$isSetting.withValue(true) {
      var dependencies = Self._current
      dependencies[keyPath: keyPath] = value
      return try Self.$_current.withValue(dependencies) {
        try operation()
      }
    }
  }

  /// Updates a single dependency for the duration of an asynchronous operation.
  ///
  /// For example, if you wanted to force the ``DependencyValues/date`` dependency to be a
  /// particular date, you can do:
  ///
  /// ```swift
  /// await DependencyValues.withValue(\.date, .constant(Date(timeIntervalSince1970: 1234567890))) {
  ///   // References to date in here are pinned to 1234567890.
  /// }
  /// ```
  ///
  /// See ``withValues(_:operation:)-1oaja`` to update multiple dependencies at once without nesting
  /// calls to `withValue`.
  ///
  /// - Parameters:
  ///   - keyPath: A key path that indicates the property of the `DependencyValues` structure to
  ///     update.
  ///   - value: The new value to set for the item specified by `keyPath`.
  ///   - operation: The operation to run with the updated dependencies.
  /// - Returns: The result returned from `operation`.
  public static func withValue<Value, R>(
    _ keyPath: WritableKeyPath<DependencyValues, Value>,
    _ value: Value,
    operation: () async throws -> R
  ) async rethrows -> R {
    try await Self.$isSetting.withValue(true) {
      var dependencies = Self._current
      dependencies[keyPath: keyPath] = value
      return try await Self.$_current.withValue(dependencies) {
        try await operation()
      }
    }
  }

  /// Updates the dependencies for the duration of a synchronous operation.
  ///
  /// Any mutations made to ``DependencyValues`` inside `updateValuesForOperation` will be visible
  /// to everything executed in the operation. For example, if you wanted to force the ``date``
  /// dependency to be a particular date, you can do:
  ///
  /// ```swift
  /// DependencyValues.withValues {
  ///   $0.date = .constant(Date(timeIntervalSince1970: 1234567890))
  /// } operation: {
  ///   // References to date in here are pinned to 1234567890.
  /// }
  /// ```
  ///
  /// See ``withValue(_:_:operation:)-3yj9d`` to update a single dependency with a constant value.
  ///
  /// - Parameters:
  ///   - updateValuesForOperation: A closure for updating the current dependency values for the
  ///     duration of the operation.
  ///   - operation: An operation to perform wherein dependencies have been overridden.
  /// - Returns: The result returned from `operation`.
  public static func withValues<R>(
    _ updateValuesForOperation: (inout Self) throws -> Void,
    operation: () throws -> R
  ) rethrows -> R {
    try Self.$isSetting.withValue(true) {
      var dependencies = Self._current
      try updateValuesForOperation(&dependencies)
      return try Self.$_current.withValue(dependencies) {
        try operation()
      }
    }
  }

  /// Updates the dependencies for the duration of an asynchronous operation.
  ///
  /// Any mutations made to ``DependencyValues`` inside `updateValuesForOperation` will be visible
  /// to everything executed in the operation. For example, if you wanted to force the
  /// ``DependencyValues/date`` dependency to be a particular date, you can do:
  ///
  /// ```swift
  /// await DependencyValues.withValues {
  ///   $0.date = .constant(Date(timeIntervalSince1970: 1234567890))
  /// } operation: {
  ///   // References to date in here are pinned to 1234567890.
  /// }
  /// ```
  ///
  /// See ``withValue(_:_:operation:)-705n`` to update a single dependency with a constant value.
  ///
  /// - Parameters:
  ///   - updateValuesForOperation: A closure for updating the current dependency values for the
  ///     duration of the operation.
  ///   - operation: An operation to perform wherein dependencies have been overridden.
  /// - Returns: The result returned from `operation`.
  public static func withValues<R>(
    _ updateValuesForOperation: (inout Self) async throws -> Void,
    operation: () async throws -> R
  ) async rethrows -> R {
    try await Self.$isSetting.withValue(true) {
      var dependencies = Self._current
      try await updateValuesForOperation(&dependencies)
      return try await Self.$_current.withValue(dependencies) {
        try await operation()
      }
    }
  }

  private var defaultValues = DefaultValues()
  private var storage: [ObjectIdentifier: AnySendable] = [:]

  /// Creates a dependency values instance.
  ///
  /// You don't typically create an instance of ``DependencyValues`` directly. Doing so would
  /// provide access only to default values. Instead, you rely on the dependency values' instance
  /// that the library manages for you when you use the ``Dependency`` property wrapper.
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
  /// with ``withValue(_:_:operation:)-705n``, and reading values with the ``Dependency`` property
  /// wrapper.
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
          guard let value = self.defaultValues.openedLive(Key.self)
          else {
            // TODO: add test coverage to this logic
            if !Self.isSetting {
              var dependencyDescription = ""
              if let fileID = Self.currentDependency.fileID,
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

              runtimeWarn(
                """
                "@Dependency(\\.\(function))" has no live implementation, but was accessed from a \
                live context.

                \(dependencyDescription)

                Every dependency registered with the library must conform to "DependencyKey", and \
                that conformance must be visible to the running application.

                To fix, make sure that "\(typeName(Key.self))" conforms to "DependencyKey" by \
                providing a live implementation of your dependency, and make sure that the \
                conformance is linked with this current application.
                """,
                file: Self.currentDependency.file ?? file,
                line: Self.currentDependency.line ?? line
              )
            }
            return self.defaultValues.test(Key.self)
          }
          return value
        case .preview:
          return self.defaultValues.preview(Key.self)
        case .test:
          var currentDependency = Self.currentDependency
          currentDependency.name = function
          return Self.$currentDependency.withValue(currentDependency) {
            self.defaultValues.test(Key.self)
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

extension DependencyValues {
  final class DefaultValues: @unchecked Sendable {
    struct StorageKey: Hashable, Sendable {
      let id: ObjectIdentifier
      let context: DependencyContext
    }

    private let lock = NSRecursiveLock()
    private var storage = [StorageKey: AnySendable]()

    func openedLive<Key: TestDependencyKey>(_ key: Key.Type) -> Key.Value?  {
      self.value(key, context: .live, default: _liveValue(key) as? Key.Value)
    }
    
    func preview<Key: TestDependencyKey>(_ key: Key.Type) -> Key.Value {
      self.value(key, context: .preview, default: Key.previewValue)!
    }

    func test<Key: TestDependencyKey>(_ key: Key.Type) -> Key.Value {
      self.value(key, context: .test, default: Key.testValue)!
    }
    
    private func value<Key: TestDependencyKey>(
      _ key: Key.Type,
      context: DependencyContext,
      default: @autoclosure () -> Key.Value?
    ) -> Key.Value? {
      let storageKey = StorageKey(id: ObjectIdentifier(key), context: context)
      self.lock.lock()
      defer { self.lock.unlock() }
      if let value = self.storage[storageKey]?.base as? Key.Value { return value }
      guard let value = `default`() else { return nil }
      self.storage[storageKey] = AnySendable(value)
      return value
    }
  }
}

