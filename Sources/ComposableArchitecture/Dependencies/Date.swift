import Foundation
import XCTestDynamicOverlay

extension DependencyValues {
  public var date: any DateGenerator {
    get { self[DateGeneratorKey.self] }
    set { self[DateGeneratorKey.self] = newValue }
  }

  private enum DateGeneratorKey: LiveDependencyKey {
    static let liveValue: any DateGenerator = LiveDateGenerator()
    static let testValue: any DateGenerator = FailingDateGenerator()
  }
}

public protocol DateGenerator {
  func callAsFunction() -> Date
}

private struct LiveDateGenerator: DateGenerator {
  @inlinable
  func callAsFunction() -> Date {
    .init()
  }
}

extension DateGenerator where Self == LiveDateGenerator {
  static var live: Self { .init() }
}

private struct FailingDateGenerator: DateGenerator {
  @inlinable
  func callAsFunction() -> Date {
    XCTFail(#"@Dependency(\.date) is failing"#)
    return .init()
  }
}

extension DateGenerator where Self == FailingDateGenerator {
  static var failing: Self { .init() }
}
