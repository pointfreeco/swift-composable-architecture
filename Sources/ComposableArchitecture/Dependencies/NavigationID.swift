extension DependencyValues {

  public var navigationID: NavigationID {
    get { self[NavigationIDKey.self] }
    set { self[NavigationIDKey.self] = newValue }
  }

  private enum NavigationIDKey: LiveDependencyKey {
    static let liveValue = NavigationID.live
    static let testValue = NavigationID.incrementing
  }
}

// TODO: make sendable
public struct NavigationID {
  public var next: () -> AnyHashable
  public var current: AnyHashable?

  static let live = Self { UUID() }
  static var incrementing: Self {
    var count = 0
    return Self {
      defer { count += 1 }
      return count
    }
  }
}
