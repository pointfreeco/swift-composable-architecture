import Foundation
import XCTestDynamicOverlay

extension DependencyValues {
  /// The current locale that features should use.
  ///
  /// By default, the locale returned from `Locale.autoupdatingCurrent` is supplied. When used
  /// from a `TestStore`, access will call to `XCTFail` when invoked, unless explicitly
  /// overridden.
  ///
  /// You can access the current locale from a feature by introducing a ``Dependency`` property
  /// wrapper to the property:
  ///
  /// ```swift
  /// final class FeatureModel: ReducerProtocol {
  ///   @Dependency(\.locale) var locale
  ///   // ...
  /// }
  /// ```
  ///
  /// To override the current locale in tests, use ``withValue(_:_:operation:)-705n``:

  /// ```swift
  /// DependencyValues.withValue(\.locale, Locale(identifier: "en_US")) {
  ///   // Assertions...
  /// }
  /// ```
  ///
  /// Or, if you are using the Composable Architecture, you can override dependencies directly
  /// on the `TestStore`:
  ///
  /// ```swift
  /// let store = TestStore(
  ///   initialState: MyFeature.State()
  ///   reducer: MyFeature()
  /// )
  ///
  /// store.dependencies.locale = Locale(identifier: "en_US")
  /// ```
  public var locale: Locale {
    get { self[LocaleKey.self] }
    set { self[LocaleKey.self] = newValue }
  }

  private enum LocaleKey: DependencyKey {
    static let liveValue = Locale.autoupdatingCurrent
    static var testValue: Locale {
      if !DependencyValues.isSetting {
        XCTFail(#"Unimplemented: @Dependency(\.locale)"#)
      }
      return .autoupdatingCurrent
    }
  }
}
