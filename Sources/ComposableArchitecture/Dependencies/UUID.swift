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

public protocol UUIDGenerator: Sendable {
  func callAsFunction() -> UUID
}

public struct LiveUUIDGenerator: UUIDGenerator {
  @inlinable
  public func callAsFunction() -> UUID {
    .init()
  }
}

extension UUIDGenerator where Self == LiveUUIDGenerator {
  public static var live: Self { .init() }
}

public struct FailingUUIDGenerator: UUIDGenerator {
  @inlinable
  public func callAsFunction() -> UUID {
    XCTFail(#"@Dependency(\.uuid) is failing"#)
    return .init()
  }
}

extension UUIDGenerator where Self == FailingUUIDGenerator {
  public static var failing: Self { .init() }
}

public final class IncrementingUUIDGenerator: UUIDGenerator {
  @usableFromInline
  var sequence = 0

  @inlinable
  public func callAsFunction() -> UUID {
    defer { self.sequence += 1 }
    return .init(uuidString: "00000000-0000-0000-0000-\(String(format: "%012x", self.sequence))")!
  }
}

extension UUIDGenerator where Self == IncrementingUUIDGenerator {
  public static var incrementing: Self { .init() }
}

public struct ConstantUUIDGenerator: UUIDGenerator {
  @usableFromInline
  let value: UUID

  @usableFromInline
  init(value: UUID) {
    self.value = value
  }

  @inlinable
  public func callAsFunction() -> UUID {
    self.value
  }
}

extension UUIDGenerator where Self == ConstantUUIDGenerator {
  public static func constant(_ uuid: UUID) -> Self { .init(value: uuid) }
}
