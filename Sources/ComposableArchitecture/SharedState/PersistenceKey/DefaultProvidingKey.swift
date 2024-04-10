/// A decorator around a persistence key that provides a built-in default value.
public struct DefaultProvidingKey<UnderlyingKey: PersistenceReaderKey>: Hashable, PersistenceReaderKey, Sendable
where UnderlyingKey: Hashable & Sendable, UnderlyingKey.Value: Hashable & Sendable {
  let key: UnderlyingKey
  let defaultValue: UnderlyingKey.Value
  init(_ key: UnderlyingKey, defaultValue: UnderlyingKey.Value) {
    self.key = key
    self.defaultValue = defaultValue
  }
  public func load(initialValue: UnderlyingKey.Value?) -> UnderlyingKey.Value? {
    self.key.load(initialValue: initialValue)
  }
  public func subscribe(
    initialValue: UnderlyingKey.Value?,
    didSet: @Sendable @escaping (UnderlyingKey.Value?) -> Void
  ) -> Shared<UnderlyingKey.Value>.Subscription {
    self.key.subscribe(initialValue: initialValue, didSet: didSet)
  }
}

extension DefaultProvidingKey: PersistenceKey where UnderlyingKey: PersistenceKey {
  public func save(_ value: Value) {
    self.key.save(value)
  }
}
