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
  public enum Environment: Sendable {
    case live, preview, test
  }

  @TaskLocal public static var current = Self()

  private var storage: [ObjectIdentifier: AnySendable] = [:]

  public init() {}

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
           ?? {
            if isPreview {
              return Environment.preview
            } else {
              return Environment.live
            }
          }()

        switch mode {
        case .live:
          guard let value = _liveValue(Key.self) as? Key.Value
          else {
            runtimeWarning(
              """
              A dependency at %@:%d is being used in a live environment without providing a live \
              implementation:

                Key:
                  %@
                Dependency:
                  %@

              Every dependency registered with the library must conform to 'LiveDependencyKey', \
              and that conformance must be visible to the running application.

              To fix, make sure that '%@' conforms to 'LiveDependencyKey' by providing a live \
              implementation of your dependency, and make sure that the conformance is linked \
              with this current application.
              """,
              [
                "\(fileID)",
                line,
                "\(typeName(Key.self))",
                "\(typeName(Key.Value.self))",
                "\(typeName(Key.self))"
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
