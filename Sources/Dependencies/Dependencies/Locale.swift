import Foundation
import XCTestDynamicOverlay

extension DependencyValues {
  /// The current locale that reducers should use.
  public var locale: Locale {
    get { self[LocaleKey.self] }
    set { self[LocaleKey.self] = newValue }
  }

  private enum LocaleKey: LiveDependencyKey {
    static let liveValue = Locale.autoupdatingCurrent
    static var testValue: Locale {
      XCTFail(#"Unimplemented: @Dependency(\.locale)"#)
      return .autoupdatingCurrent
    }
  }
}
