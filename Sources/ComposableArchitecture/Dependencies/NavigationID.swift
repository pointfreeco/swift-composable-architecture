extension DependencyValues {
  public var navigationID: NavigationID {
    get { self[NavigationIDKey.self] }
    set { self[NavigationIDKey.self] = newValue }
  }

  private enum NavigationIDKey: LiveDependencyKey {
    static let liveValue = NavigationID.live
    static var testValue = NavigationID.live
  }
}

// TODO: Make `Sendable`
// TODO: Should this be called `Navigation` with `nextID` and `currentID`?
public struct NavigationID {
  public var current: AnyHashable?
  // TODO: Runtime warn by default? (when not presented)
  // TODO: Should this be optional? Should it be:
  // - navigation.current?.id
  // - navigation.current?.dismiss()
  // - navigation.nextID()
  // - navigation.nextID.peek() // requires state
  public var dismiss: @Sendable () async -> Void = {}
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
