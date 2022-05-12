import Foundation

extension DependencyValues {
  public var notificationCenter: NotificationCenter {
    get { self[NotificationCenterKey.self] }
    set { self[NotificationCenterKey.self] = newValue }
  }

  private enum NotificationCenterKey: LiveDependencyKey {
    static let liveValue = NotificationCenter.default
    static let testValue = NotificationCenter.default
  }
}
