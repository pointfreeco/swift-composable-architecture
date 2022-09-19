extension DependencyValues {
  var navigationID: NavigationID {
    get { self[NavigationID.self] }
    set { self[NavigationID.self] = newValue }
  }
}

// TODO: Fix sendability
public struct NavigationID: @unchecked Sendable {
  public var current: AnyHashable?
  public var next: @Sendable () -> AnyHashable
}

extension NavigationID: DependencyKey {
  public static let liveValue = {
    let id = UUIDGenerator.live
    return Self { id() }
  }()

  public static var testValue = {
    let id = UUIDGenerator.incrementing
    return Self { id() }
  }()
}
