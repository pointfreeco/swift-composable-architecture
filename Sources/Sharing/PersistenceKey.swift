public protocol PersistenceKey<Value>: Hashable {
  associatedtype Value
  func load(initialValue: Value?) -> Value?  // TODO: Should this be throwing?
  func save(_ value: Value)
  func subscribe(
    initialValue: Value?, didSet: @escaping (_ newValue: Value?) -> Void
  ) -> Shared<Value>.Subscription
}

extension PersistenceKey {
  public func subscribe(
    initialValue: Value?, didSet: @escaping (_ newValue: Value?) -> Void
  ) -> Shared<Value>.Subscription {
    Shared.Subscription {}
  }
}

extension Shared {
  public class Subscription {
    let onCancel: () -> Void
    public init(onCancel: @escaping () -> Void) {
      self.onCancel = onCancel
    }
    deinit {
      self.cancel()
    }
    func cancel() {
      self.onCancel()
    }
  }
}
