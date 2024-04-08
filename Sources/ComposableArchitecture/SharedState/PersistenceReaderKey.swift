import Foundation

public protocol PersistenceReaderKey<Value>: Hashable {
  associatedtype Value

  /// Loads the freshest value from storage. Returns `nil` if there is no value in storage.
  func load(initialValue: Value?) -> Value?  // TODO: Should this be throwing?

  /// Subscribes to external updates.
  func subscribe(
    initialValue: Value?, didSet: @escaping (_ newValue: Value?) -> Void
  ) -> Shared<Value>.Subscription
}

extension PersistenceReaderKey where Self == NotificationReaderKey<Bool> {
  public static var isLowPowerEnabled: Self {
    NotificationReaderKey(name: .NSProcessInfoPowerStateDidChange) { _ in
      ProcessInfo.processInfo.isLowPowerModeEnabled
    }
  }
}

public struct NotificationReaderKey<Value>: PersistenceReaderKey {
  public let name: Notification.Name
  public let transform: (Notification) -> Value

  public init(name: Notification.Name, transform: @escaping (Notification) -> Value) {
    self.name = name
    self.transform = transform
  }

  public func load(initialValue: Value?) -> Value? {
    initialValue
  }

  public func subscribe(
    initialValue: Value?,
    didSet: @escaping (Value?) -> Void
  ) -> Shared<Value>.Subscription {
    let token = NotificationCenter.default.addObserver(
      forName: name,
      object: nil,
      queue: nil,
      using: { notification in
      }
    )
    return Shared.Subscription {
      NotificationCenter.default.removeObserver(token)
    }
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.name == rhs.name
  }
  public func hash(into hasher: inout Hasher) {
    hasher.combine(name)
  }
}
