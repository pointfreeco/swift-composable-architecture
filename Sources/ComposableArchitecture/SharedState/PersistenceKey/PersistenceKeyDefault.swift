/// A persistence key that provides a default value to an existing persistence key.
public struct PersistenceKeyDefault<Base: PersistenceReaderKey>: PersistenceReaderKey {
  let base: Base
  let defaultValue: Base.Value

  public init(_ key: Base, _ value: Base.Value) {
    self.base = key
    self.defaultValue = value
  }

  public func load(initialValue: Base.Value?) -> Base.Value? {
    self.base.load(initialValue: initialValue ?? self.defaultValue)
  }

  public func subscribe(
    initialValue: Base.Value?,
    didSet: @Sendable @escaping (Base.Value?) -> Void
  ) -> Shared<Base.Value>.Subscription {
    self.base.subscribe(initialValue: initialValue, didSet: didSet)
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.base)
  }
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.base == rhs.base
  }
}

extension PersistenceKeyDefault: PersistenceKey where Base: PersistenceKey {
  public func save(_ value: Value) {
    self.base.save(value)
  }
}
