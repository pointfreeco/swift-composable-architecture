extension DependencyValues {

  public var navigationID: NavigationID {
    get { self[NavigationIDKey.self] }
    set { self[NavigationIDKey.self] = newValue }
  }

  private enum NavigationIDKey: LiveDependencyKey {
    static let liveValue = NavigationID.live
    static var testValue: NavigationID { NavigationID.incrementing }
  }
}

// TODO: make sendable
public struct NavigationID {
  public var next: () -> AnyHashable
  public var current: AnyHashable?

  public static let live = Self { UUID() }
  public static var incrementing: Self {
    var count = 0
    return Self {
      defer { count += 1 }
      return count
    }
  }
}
