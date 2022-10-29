/// A property wrapper for accessing dependencies.
///
/// All dependencies are stored in ``DependencyValues`` and one uses this property wrapper to
/// gain access to a particular dependency. Typically it used to provide dependencies to features
/// such as an observable object:
///
/// ```swift
/// final class FeatureModel: ObservableObject {
///   @Dependency(\.apiClient) var apiClient
///   @Dependency(\.continuousClock) var clock
///   @Dependency(\.uuid) var uuid
///
///   // ...
/// }
/// ```
///
/// Or, if you are using the Composable Architecture:
///
/// ```swift
/// struct Feature: ReducerProtocol {
///   @Dependency(\.apiClient) var apiClient
///   @Dependency(\.continuousClock) var clock
///   @Dependency(\.uuid) var uuid
///
///   // ...
/// }
/// ```
///
/// But it can be used in other situations too, such as a shared helper function of constructing
/// an effect that can be used from multiple reducers:
///
/// ```swift
/// func sharedEffect() async throws -> Action {
///   @Dependency(\.apiClient) var apiClient
///   @Dependency(\.continuousClock) var clock
///
///   // ...
/// }
/// ```
///
/// For the complete list of dependency values provided by the library, see the properties of the
/// ``DependencyValues`` structure. For information about creating custom dependency values,
/// see the ``DependencyKey`` protocol.
@propertyWrapper
public struct Dependency<Value>: @unchecked Sendable {
  // NB: Key paths do not conform to sendable and are instead diagnosed at the time of forming the
  //     literal.
  private let keyPath: KeyPath<DependencyValues, Value>
  private let file: StaticString
  private let fileID: StaticString
  private let line: UInt

  /// Creates a dependency property to read the specified key path.
  ///
  /// Don't call this initializer directly. Instead, declare a property with the `Dependency`
  /// property wrapper, and provide the key path of the dependency value that the property should
  /// reflect:
  ///
  /// ```swift
  /// final class FeatureModel: ObservableObject {
  ///   @Dependency(\.date) var date
  ///
  ///   // ...
  /// }
  /// ```
  ///
  /// - Parameter keyPath: A key path to a specific resulting value.
  public init(
    _ keyPath: KeyPath<DependencyValues, Value>,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.keyPath = keyPath
    self.file = file
    self.fileID = fileID
    self.line = line
  }

  /// The current value of the dependency property.
  public var wrappedValue: Value {
    #if DEBUG
      var currentDependency = DependencyValues.currentDependency
      currentDependency.file = self.file
      currentDependency.fileID = self.fileID
      currentDependency.line = self.line
      return DependencyValues.$currentDependency.withValue(currentDependency) {
        DependencyValues._current[keyPath: self.keyPath]
      }
    #else
      return DependencyValues._current[keyPath: self.keyPath]
    #endif
  }
}
