extension DependencyValues {
  public var mainRunLoop: AnySchedulerOf<RunLoop> {
    get { self[MainRunLoopKey.self] }
    set { self[MainRunLoopKey.self] = newValue }
  }

  private enum MainRunLoopKey: LiveDependencyKey {
    static let liveValue = AnySchedulerOf<RunLoop>.main
    static let testValue = AnySchedulerOf<RunLoop>.failing
  }
}
