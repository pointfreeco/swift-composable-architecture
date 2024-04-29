/// A persistence key that provides a default value to an existing persistence key.
///
/// Use this persistence key when constructing type-safe keys (see
/// <doc:SharingState#Type-safe-keys> for more info) to provide a deafult that is used instead of
/// providing one at the call site of using [`@Shared`](<doc:Shared>).
///
/// For example, if an `isOn` value is backed by user defaults and it should default to `false` when
/// there is no value in user defaults, then you can define a persistence key like so:
///
/// ```swift
/// extension PersistenceReaderKey where Self == PersistenceKeyDefault<AppStorageKey<Bool>> {
///   static var isOn: Self {
///     PersistenceKeyDefault(.appStorage("isOn"), false)
///   }
/// }
/// ```
///
/// And then use it like so:
///
/// ```swift
/// struct State {
///   @Shared(.isOn) var isOn
/// }
/// ```
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
