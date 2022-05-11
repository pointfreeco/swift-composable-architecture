import Foundation
import XCTestDynamicOverlay

extension DependencyValues {
  public var uuid: any UUIDGenerator {
    get { self[UUIDGeneratorKey.self] }
    set { self[UUIDGeneratorKey.self] = newValue }
  }
}

public protocol UUIDGenerator {
  func callAsFunction() -> UUID
}

private struct FailingUUIDGenerator: UUIDGenerator {
  @inlinable
  func callAsFunction() -> UUID {
    XCTFail(#"@Dependency(\.uuid) is not set"#)
    return UUID()
  }
}

private struct LiveUUIDGenerator: UUIDGenerator {
  @inlinable
  func callAsFunction() -> UUID {
    UUID()
  }
}

private enum UUIDGeneratorKey: LiveDependencyKey {
  static let liveValue: any UUIDGenerator = LiveUUIDGenerator()
  static let testValue: any UUIDGenerator = FailingUUIDGenerator()
}
