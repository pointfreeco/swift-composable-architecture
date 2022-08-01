import Foundation
import XCTestDynamicOverlay

extension DependencyValues {
  public var date: any DateGenerator {
    get { self[DateGeneratorKey.self] }
    set { self[DateGeneratorKey.self] = newValue }
  }

  private enum DateGeneratorKey: LiveDependencyKey {
    // TODO: Benchmark difference between existential overhead vs. struct with non-inlined closures.
    static let liveValue: any DateGenerator = LiveDateGenerator()
    static let testValue: any DateGenerator = UnimplementedDateGenerator()
  }
}

public protocol DateGenerator {
  func callAsFunction() -> Date
}

private struct LiveDateGenerator: DateGenerator {
  @inlinable
  func callAsFunction() -> Date {
    Date()
  }
}

extension DateGenerator where Self == LiveDateGenerator {
  static var live: Self { Self() }
}

private struct UnimplementedDateGenerator: DateGenerator {
  @inlinable
  func callAsFunction() -> Date {
    XCTFail(#"Unimplemented: @Dependency(\.date)"#)
    return Date()
  }
}

extension DateGenerator where Self == UnimplementedDateGenerator {
  static var unimplemented: Self { Self() }
}
