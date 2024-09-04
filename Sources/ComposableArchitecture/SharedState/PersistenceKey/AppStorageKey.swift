import Dependencies
import Foundation

extension PersistenceReaderKey {
  /// Creates a persistence key that can read and write to a boolean user default.
  ///
  /// - Parameter key: The key to read and write the value to in the user defaults store.
  /// - Returns: A user defaults persistence key.
  public static func appStorage(_ key: String) -> Self
  where Self == AppStorageKey<Bool> {
    AppStorageKey(key)
  }

  /// Creates a persistence key that can read and write to an integer user default.
  ///
  /// - Parameter key: The key to read and write the value to in the user defaults store.
  /// - Returns: A user defaults persistence key.
  public static func appStorage(_ key: String) -> Self
  where Self == AppStorageKey<Int> {
    AppStorageKey(key)
  }

  /// Creates a persistence key that can read and write to a double user default.
  ///
  /// - Parameter key: The key to read and write the value to in the user defaults store.
  /// - Returns: A user defaults persistence key.
  public static func appStorage(_ key: String) -> Self
  where Self == AppStorageKey<Double> {
    AppStorageKey(key)
  }

  /// Creates a persistence key that can read and write to a string user default.
  ///
  /// - Parameter key: The key to read and write the value to in the user defaults store.
  /// - Returns: A user defaults persistence key.
  public static func appStorage(_ key: String) -> Self
  where Self == AppStorageKey<String> {
    AppStorageKey(key)
  }

  /// Creates a persistence key that can read and write to a URL user default.
  ///
  /// - Parameter key: The key to read and write the value to in the user defaults store.
  /// - Returns: A user defaults persistence key.
  public static func appStorage(_ key: String) -> Self
  where Self == AppStorageKey<URL> {
    AppStorageKey(key)
  }

  /// Creates a persistence key that can read and write to a user default as data.
  ///
  /// - Parameter key: The key to read and write the value to in the user defaults store.
  /// - Returns: A user defaults persistence key.
  public static func appStorage(_ key: String) -> Self
  where Self == AppStorageKey<Data> {
    AppStorageKey(key)
  }

  /// Creates a persistence key that can read and write to an integer user default, transforming
  /// that to a `RawRepresentable` data type.
  ///
  /// - Parameter key: The key to read and write the value to in the user defaults store.
  /// - Returns: A user defaults persistence key.
  public static func appStorage<Value: RawRepresentable<Int>>(_ key: String) -> Self
  where Self == AppStorageKey<Value> {
    AppStorageKey(key)
  }

  /// Creates a persistence key that can read and write to a string user default, transforming
  /// that to a `RawRepresentable` data type.
  ///
  /// - Parameter key: The key to read and write the value to in the user defaults store.
  /// - Returns: A user defaults persistence key.
  public static func appStorage<Value: RawRepresentable<String>>(_ key: String) -> Self
  where Self == AppStorageKey<Value> {
    AppStorageKey(key)
  }

  /// Creates a persistence key that can read and write to an optional boolean user default.
  ///
  /// - Parameter key: The key to read and write the value to in the user defaults store.
  /// - Returns: A user defaults persistence key.
  public static func appStorage(_ key: String) -> Self
  where Self == AppStorageKey<Bool?> {
    AppStorageKey(key)
  }

  /// Creates a persistence key that can read and write to an optional integer user default.
  ///
  /// - Parameter key: The key to read and write the value to in the user defaults store.
  /// - Returns: A user defaults persistence key.
  public static func appStorage(_ key: String) -> Self
  where Self == AppStorageKey<Int?> {
    AppStorageKey(key)
  }

  /// Creates a persistence key that can read and write to an optional double user default.
  ///
  /// - Parameter key: The key to read and write the value to in the user defaults store.
  /// - Returns: A user defaults persistence key.
  public static func appStorage(_ key: String) -> Self
  where Self == AppStorageKey<Double?> {
    AppStorageKey(key)
  }

  /// Creates a persistence key that can read and write to an optional string user default.
  ///
  /// - Parameter key: The key to read and write the value to in the user defaults store.
  /// - Returns: A user defaults persistence key.
  public static func appStorage(_ key: String) -> Self
  where Self == AppStorageKey<String?> {
    AppStorageKey(key)
  }

  /// Creates a persistence key that can read and write to an optional URL user default.
  ///
  /// - Parameter key: The key to read and write the value to in the user defaults store.
  /// - Returns: A user defaults persistence key.
  public static func appStorage(_ key: String) -> Self
  where Self == AppStorageKey<URL?> {
    AppStorageKey(key)
  }

  /// Creates a persistence key that can read and write to a user default as optional data.
  ///
  /// - Parameter key: The key to read and write the value to in the user defaults store.
  /// - Returns: A user defaults persistence key.
  public static func appStorage(_ key: String) -> Self
  where Self == AppStorageKey<Data?> {
    AppStorageKey(key)
  }

  /// Creates a persistence key that can read and write to an optional integer user default,
  /// transforming that to a `RawRepresentable` data type.
  ///
  /// - Parameter key: The key to read and write the value to in the user defaults store.
  /// - Returns: A user defaults persistence key.
  public static func appStorage<Value: RawRepresentable>(_ key: String) -> Self
  where Value.RawValue == Int, Self == AppStorageKey<Value?> {
    AppStorageKey(key)
  }

  /// Creates a persistence key that can read and write to an optional string user default,
  /// transforming that to a `RawRepresentable` data type.
  ///
  /// - Parameter key: The key to read and write the value to in the user defaults store.
  /// - Returns: A user defaults persistence key.
  public static func appStorage<Value: RawRepresentable>(_ key: String) -> Self
  where Value.RawValue == String, Self == AppStorageKey<Value?> {
    AppStorageKey(key)
  }
}

/// A type defining a user defaults persistence strategy.
///
/// See ``PersistenceReaderKey/appStorage(_:)-4l5b`` to create values of this type.
public struct AppStorageKey<Value> {
  private let lookup: any Lookup<Value>
  private let key: String
  private let store: UserDefaults

  public var id: AnyHashable {
    AppStorageKeyID(key: self.key, store: self.store)
  }

  fileprivate init(_ key: String) where Value == Bool {
    @Dependency(\.defaultAppStorage) var store
    self.lookup = CastableLookup()
    self.key = key
    self.store = store
  }

  fileprivate init(_ key: String) where Value == Int {
    @Dependency(\.defaultAppStorage) var store
    self.lookup = CastableLookup()
    self.key = key
    self.store = store
  }

  fileprivate init(_ key: String) where Value == Double {
    @Dependency(\.defaultAppStorage) var store
    self.lookup = CastableLookup()
    self.key = key
    self.store = store
  }

  fileprivate init(_ key: String) where Value == String {
    @Dependency(\.defaultAppStorage) var store
    self.lookup = CastableLookup()
    self.key = key
    self.store = store
  }

  fileprivate init(_ key: String) where Value == URL {
    @Dependency(\.defaultAppStorage) var store
    self.lookup = URLLookup()
    self.key = key
    self.store = store
  }

  fileprivate init(_ key: String) where Value == Data {
    @Dependency(\.defaultAppStorage) var store
    self.lookup = CastableLookup()
    self.key = key
    self.store = store
  }

  fileprivate init(_ key: String) where Value: RawRepresentable<Int> {
    @Dependency(\.defaultAppStorage) var store
    self.lookup = RawRepresentableLookup(base: CastableLookup())
    self.key = key
    self.store = store
  }

  fileprivate init(_ key: String) where Value: RawRepresentable<String> {
    @Dependency(\.defaultAppStorage) var store
    self.lookup = RawRepresentableLookup(base: CastableLookup())
    self.key = key
    self.store = store
  }

  fileprivate init(_ key: String) where Value == Bool? {
    @Dependency(\.defaultAppStorage) var store
    self.lookup = OptionalLookup(base: CastableLookup())
    self.key = key
    self.store = store
  }

  fileprivate init(_ key: String) where Value == Int? {
    @Dependency(\.defaultAppStorage) var store
    self.lookup = OptionalLookup(base: CastableLookup())
    self.key = key
    self.store = store
  }

  fileprivate init(_ key: String) where Value == Double? {
    @Dependency(\.defaultAppStorage) var store
    self.lookup = OptionalLookup(base: CastableLookup())
    self.key = key
    self.store = store
  }

  fileprivate init(_ key: String) where Value == String? {
    @Dependency(\.defaultAppStorage) var store
    self.lookup = OptionalLookup(base: CastableLookup())
    self.key = key
    self.store = store
  }

  fileprivate init(_ key: String) where Value == URL? {
    @Dependency(\.defaultAppStorage) var store
    self.lookup = OptionalLookup(base: URLLookup())
    self.key = key
    self.store = store
  }

  fileprivate init(_ key: String) where Value == Data? {
    @Dependency(\.defaultAppStorage) var store
    self.lookup = OptionalLookup(base: CastableLookup())
    self.key = key
    self.store = store
  }

  fileprivate init<R: RawRepresentable<Int>>(_ key: String) where Value == R? {
    @Dependency(\.defaultAppStorage) var store
    self.lookup = OptionalLookup(base: RawRepresentableLookup(base: CastableLookup()))
    self.key = key
    self.store = store
  }

  fileprivate init<R: RawRepresentable<String>>(_ key: String) where Value == R? {
    @Dependency(\.defaultAppStorage) var store
    self.lookup = OptionalLookup(base: RawRepresentableLookup(base: CastableLookup()))
    self.key = key
    self.store = store
  }
}

extension AppStorageKey: PersistenceKey {
  public func load(initialValue: Value?) -> Value? {
    self.lookup.loadValue(from: self.store, at: self.key, default: initialValue)
  }

  public func save(_ value: Value) {
    self.lookup.saveValue(value, to: self.store, at: self.key)
  }

  public func subscribe(
    initialValue: Value?,
    didSet: @escaping @Sendable (_ newValue: Value?) -> Void
  ) -> Shared<Value>.Subscription {
    let previousValue = LockIsolated(initialValue)
    let userDefaultsDidChange = NotificationCenter.default.addObserver(
      forName: UserDefaults.didChangeNotification,
      object: self.store,
      queue: nil
    ) { _ in
      let newValue = load(initialValue: initialValue)
      defer { previousValue.withValue { $0 = newValue } }
      guard
        !(_isEqual(newValue as Any, previousValue.value as Any) ?? false)
          || (_isEqual(newValue as Any, initialValue as Any) ?? true)
      else {
        return
      }
      guard !SharedAppStorageLocals.isSetting
      else { return }
      didSet(newValue)
    }
    let willEnterForeground: (any NSObjectProtocol)?
    if let willEnterForegroundNotificationName {
      willEnterForeground = NotificationCenter.default.addObserver(
        forName: willEnterForegroundNotificationName,
        object: nil,
        queue: nil
      ) { _ in
        didSet(load(initialValue: initialValue))
      }
    } else {
      willEnterForeground = nil
    }
    return Shared.Subscription {
      NotificationCenter.default.removeObserver(userDefaultsDidChange)
      if let willEnterForeground {
        NotificationCenter.default.removeObserver(willEnterForeground)
      }
    }
  }
}

private struct AppStorageKeyID: Hashable {
  let key: String
  let store: UserDefaults
}

extension DependencyValues {
  public var defaultAppStorage: UserDefaults {
    get { self[DefaultAppStorageKey.self].value }
    set { self[DefaultAppStorageKey.self].value = newValue }
  }
}

private enum DefaultAppStorageKey: DependencyKey {
  static var testValue: UncheckedSendable<UserDefaults> {
    UncheckedSendable(
      UserDefaults(
        suiteName:
          "\(NSTemporaryDirectory())co.pointfree.ComposableArchitecture.\(UUID().uuidString)"
      )!
    )
  }
  static var previewValue: UncheckedSendable<UserDefaults> {
    Self.testValue
  }
  static var liveValue: UncheckedSendable<UserDefaults> {
    UncheckedSendable(UserDefaults.standard)
  }
}

// NB: This is mainly used for tests, where observer notifications can bleed across cases.
private enum SharedAppStorageLocals {
  @TaskLocal static var isSetting = false
}

private protocol Lookup<Value> {
  associatedtype Value
  func loadValue(from store: UserDefaults, at key: String, default defaultValue: Value?) -> Value?
  func saveValue(_ newValue: Value, to store: UserDefaults, at key: String)
}

private struct CastableLookup<Value>: Lookup {
  func loadValue(
    from store: UserDefaults,
    at key: String,
    default defaultValue: Value?
  ) -> Value? {
    guard let value = store.object(forKey: key) as? Value
    else {
      guard !SharedAppStorageLocals.isSetting
      else { return defaultValue }

      SharedAppStorageLocals.$isSetting.withValue(true) {
        store.setValue(defaultValue, forKey: key)
      }
      return defaultValue
    }
    return value
  }

  func saveValue(_ newValue: Value, to store: UserDefaults, at key: String) {
    SharedAppStorageLocals.$isSetting.withValue(true) {
      store.setValue(newValue, forKey: key)
    }
  }
}

/// Lookup implementation tuned for URL values.
/// For URLs, dedicated UserDefaults APIs for getting/setting need to be called that convert the URL from/to Data.
/// Calling setValue with a URL causes a NSInvalidArgumentException exception.
private struct URLLookup: Lookup {
  typealias Value = URL

  func loadValue(from store: UserDefaults, at key: String, default defaultValue: URL?) -> URL? {
    guard let value = store.url(forKey: key)
    else {
      guard !SharedAppStorageLocals.isSetting
      else { return defaultValue }

      SharedAppStorageLocals.$isSetting.withValue(true) {
        store.set(defaultValue, forKey: key)
      }
      return defaultValue
    }
    return value
  }

  func saveValue(_ newValue: URL, to store: UserDefaults, at key: String) {
    SharedAppStorageLocals.$isSetting.withValue(true) {
      store.set(newValue, forKey: key)
    }
  }
}

private struct RawRepresentableLookup<Value: RawRepresentable, Base: Lookup>: Lookup
where Value.RawValue == Base.Value {
  let base: Base
  func loadValue(
    from store: UserDefaults, at key: String, default defaultValue: Value?
  ) -> Value? {
    base.loadValue(from: store, at: key, default: defaultValue?.rawValue)
      .flatMap(Value.init(rawValue:))
      ?? defaultValue
  }
  func saveValue(_ newValue: Value, to store: UserDefaults, at key: String) {
    base.saveValue(newValue.rawValue, to: store, at: key)
  }
}

private struct OptionalLookup<Base: Lookup>: Lookup {
  let base: Base
  func loadValue(
    from store: UserDefaults, at key: String, default defaultValue: Base.Value??
  ) -> Base.Value?? {
    base.loadValue(from: store, at: key, default: defaultValue ?? nil)
  }
  func saveValue(_ newValue: Base.Value?, to store: UserDefaults, at key: String) {
    if let newValue {
      base.saveValue(newValue, to: store, at: key)
    } else {
      store.removeObject(forKey: key)
    }
  }
}
