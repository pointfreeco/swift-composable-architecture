import Foundation
import XCTestDynamicOverlay

extension DependencyValues {
  public var uuid: any UUIDGenerator {
    get { self[UUIDGeneratorKey.self] }
    set { self[UUIDGeneratorKey.self] = newValue }
  }

  private enum UUIDGeneratorKey: LiveDependencyKey {
    static let liveValue: any UUIDGenerator = LiveUUIDGenerator()
    static let testValue: any UUIDGenerator = FailingUUIDGenerator()
  }
}

public protocol UUIDGenerator {
  func callAsFunction() -> UUID
}

private struct LiveUUIDGenerator: UUIDGenerator {
  @inlinable
  func callAsFunction() -> UUID {
    .init()
  }
}

extension UUIDGenerator where Self == LiveUUIDGenerator {
  static var live: Self { .init() }
}

private struct FailingUUIDGenerator: UUIDGenerator {
  @inlinable
  func callAsFunction() -> UUID {
    XCTFail(#"@Dependency(\.uuid) is failing"#)
    return .init()
  }
}

extension UUIDGenerator where Self == FailingUUIDGenerator {
  static var failing: Self { .init() }
}
