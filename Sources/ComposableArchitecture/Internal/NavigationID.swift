extension DependencyValues {
  var navigationID: NavigationID {
    get { self[NavigationIDKey.self] }
    set { self[NavigationIDKey.self] = newValue }
  }

  private enum NavigationIDKey: LiveDependencyKey {
    static let liveValue = NavigationID.live
    static let testValue = NavigationID.live
  }
}

public struct NavigationID {
  public var current: AnyHashable?
  public var next: () -> AnyHashable

  public static let live = Self { UUID() }
  public static var incrementing: Self {
    var count = 1
    return Self {
      defer { count += 1 }
      return count
    }
  }
}
