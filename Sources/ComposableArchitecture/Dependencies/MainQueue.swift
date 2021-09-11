private enum MainQueueKey: DependencyKey {
  static let defaultValue = AnySchedulerOf<DispatchQueue>.main
  static let testValue = AnySchedulerOf<DispatchQueue>.failing
}

extension DependencyValues {
  public var mainQueue: AnySchedulerOf<DispatchQueue> {
    get { self[MainQueueKey.self] }
    set { self[MainQueueKey.self] = newValue }
  }
}
