import XCTestDynamicOverlay

extension DependencyValues {
  public var uuid: UUIDDependency {
    get { self[UUIDKey.self] }
    set { self[UUIDKey.self] = newValue }
  }
}

private enum UUIDKey: DependencyKey {
  static let defaultValue = UUIDDependency.live
  static let testValue = UUIDDependency.failing
}

public struct UUIDDependency {
  public var uuid: () -> UUID

  public static let live = Self(uuid: UUID.init)

  public static let failing = Self {
    XCTFail(#"@Dependency(\.uuid) is unimplemented"#)
    return UUID()
  }

  public static var incrementing: Self {
    var uuid = 0
    return Self(
      uuid: {
        defer { uuid += 1 }
        return UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012x", uuid))")!
      }
    )
  }

  public func callAsFunction() -> UUID {
    self.uuid()
  }
}
