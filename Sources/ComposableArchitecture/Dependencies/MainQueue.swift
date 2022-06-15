extension DependencyValues {
  public var mainQueue: AnySchedulerOf<DispatchQueue> {
    get { self[MainQueueKey.self] }
    set { self[MainQueueKey.self] = newValue }
  }

  private enum MainQueueKey: LiveDependencyKey {
    static let liveValue = AnySchedulerOf<DispatchQueue>.main
    static let testValue = AnySchedulerOf<DispatchQueue>.failing
  }
}
