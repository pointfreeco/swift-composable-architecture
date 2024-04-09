import Foundation

public protocol PersistenceReaderKey<Value>: Hashable {
  associatedtype Value

  /// Loads the freshest value from storage. Returns `nil` if there is no value in storage.
  func load(initialValue: Value?) -> Value?  // TODO: Should this be throwing?

  /// Subscribes to external updates.
  func subscribe(
    initialValue: Value?,
    didSet: @Sendable @escaping (_ newValue: Value?) -> Void
  ) -> Shared<Value>.Subscription
}
