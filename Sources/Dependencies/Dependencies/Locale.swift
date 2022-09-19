import Foundation
import XCTestDynamicOverlay

#if swift(>=5.6)
  extension DependencyValues {
    /// The current locale that reducers should use.
    ///
    /// By default, the locale returned from `Locale.autoupdatingCurrent` is supplied. When used
    /// from a `TestStore`, access will call to `XCTFail` when invoked, unless explicitly
    /// overridden:
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
        XCTFail(#"Unimplemented: @Dependency(\.locale)"#)
        return .autoupdatingCurrent
      }
    }
  }
#endif
