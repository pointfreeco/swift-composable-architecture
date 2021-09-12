import Foundation

private enum MainRunLoopKey: DependencyKey {
  static let defaultValue = AnySchedulerOf<RunLoop>.main
  static let testValue = AnySchedulerOf<RunLoop>.failing
}

extension DependencyValues {
  public var mainRunLoop: AnySchedulerOf<RunLoop> {
    get { self[MainRunLoopKey.self] }
    set { self[MainRunLoopKey.self] = newValue }
  }
}
