extension DependencyValues {

  public var incrementing: @Sendable () -> Int {
    get { self[Incrementing.self] }
    set { self[Incrementing.self] = newValue }
  }

  private enum Incrementing: LiveDependencyKey {
    static let liveValue = live()
    static let testValue = live()
  }
}

// TODO: make sendable
private func live() -> () -> Int {
  var count = 0
  return {
    defer { count += 1 }
    return count
  }
}
