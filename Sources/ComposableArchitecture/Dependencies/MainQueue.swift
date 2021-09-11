private enum MainQueueKey: DependencyKey {
  static var defaultValue = AnySchedulerOf<DispatchQueue>.main
}

extension DependencyValues {
  public var mainQueue: AnySchedulerOf<DispatchQueue> {
    get { self[MainQueueKey.self] }
    set { self[MainQueueKey.self] = newValue }
  }
}
