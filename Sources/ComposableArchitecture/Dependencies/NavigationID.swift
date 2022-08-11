extension DependencyValues {
  public var dismiss: DismissEffect {
    get { self[DismissKey.self] }
    set { self[DismissKey.self] = newValue }
  }

  var navigationID: NavigationID {
    get { self[NavigationIDKey.self] }
    set { self[NavigationIDKey.self] = newValue }
  }

  private enum DismissKey: LiveDependencyKey {
    static let liveValue = DismissEffect()
    static var testValue = DismissEffect()
  }

  private enum NavigationIDKey: LiveDependencyKey {
    static let liveValue = NavigationID.live
    static let testValue = NavigationID.live
  }
}

public struct DismissEffect: Sendable {
  private var dismiss: (@Sendable () async -> Void)?

  public func callAsFunction(
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) async {
    guard let dismiss = self.dismiss
    else {
      runtimeWarning(
        """
        Dismissed from "%@:%d".
        """,
        [
          "\(fileID)",
          line
        ],
        file: file,
        line: line
      )
      return
    }
    await dismiss()
  }
}

extension DismissEffect {
  public init(_ dismiss: @escaping @Sendable () async -> Void) {
    self.dismiss = dismiss
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
