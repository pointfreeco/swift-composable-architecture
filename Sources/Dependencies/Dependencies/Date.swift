import Foundation
import XCTestDynamicOverlay

extension DependencyValues {
  /// A dependency that returns the current date.
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

// TODO: use struct instead, and same for UUID
public protocol DateGenerator: Sendable {
  func callAsFunction() -> Date
}

extension DateGenerator where Self == LiveDateGenerator {
  public static var live: Self { Self() }
}

public struct LiveDateGenerator: DateGenerator {
  @inlinable
  public func callAsFunction() -> Date {
    Date()
  }
}

public struct ConstantDateGenerator: DateGenerator {
  public let constant: Date
  public init(_ constant: Date) {
    self.constant = constant
  }
  @inlinable
  public func callAsFunction() -> Date {
    self.constant
  }
}

extension DateGenerator where Self == ConstantDateGenerator {
  public static func constant(_ date: Date) -> Self { .init(date) }
}

extension DateGenerator where Self == UnimplementedDateGenerator {
  public static var unimplemented: Self { Self() }
}

public struct UnimplementedDateGenerator: DateGenerator {
  @inlinable
  public func callAsFunction() -> Date {
    XCTFail(#"Unimplemented: @Dependency(\.date)"#)
    return Date()
  }
}
