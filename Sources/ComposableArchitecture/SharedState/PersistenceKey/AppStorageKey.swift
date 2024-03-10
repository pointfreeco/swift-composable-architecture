#if canImport(Perception)
  import Foundation

  extension PersistenceKey {
    /// Creates a persistence key for sharing data in user defaults given a key path.
    ///
    /// For example, one could initialize a key with the date and time at which the application was
    /// most recently launched, and access this date from anywhere using the ``Shared`` property
    /// wrapper:
    ///
    /// ```swift
    /// @Shared(.inMemory("appLaunchedAt")) var appLaunchedAt = Date()
    /// ```
    ///
    /// - Parameter key: A string key identifying a value to share in memory.
    /// - Returns: A persistence key.
    public static func appStorage<Value>(
      _ keyPath: ReferenceWritableKeyPath<UserDefaults, Value>
    ) -> Self where Self == AppStorageKey<Value> {
      AppStorageKey(keyPath)
    }

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
    public static func appStorage<Value: RawRepresentable>(_ key: String) -> Self
    where Value.RawValue == Int, Self == AppStorageKey<Value> {
      AppStorageKey(key)
    }

    /// Creates a persistence key that can read and write to a string user default, transforming
    /// that to a `RawRepresentable` data type.
    ///
    /// - Parameter key: The key to read and write the value to in the user defaults store.
    /// - Returns: A user defaults persistence key.
    public static func appStorage<Value: RawRepresentable>(_ key: String) -> Self
    where Value.RawValue == String, Self == AppStorageKey<Value> {
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

  /// A type defining a user defaults persistence strategy
  ///
  /// See ``PersistenceKey/appStorage(_:)-9zd2f`` to create values of this type.
  public struct AppStorageKey<Value> {
    private let _load: () -> Value?
    private let _save: (Value) -> Void
    private let key: Key
    private let store: UserDefaults

    private enum Key: Hashable {
      case string(String)
      case keyPath(ReferenceWritableKeyPath<UserDefaults, Value>)
    }

    public init(_ keyPath: ReferenceWritableKeyPath<UserDefaults, Value>) {
      @Dependency(\.defaultAppStorage) var store
      self._load = { [store] in store[keyPath: keyPath] }
      self._save = { [store] in store[keyPath: keyPath] = $0 }
      self.key = .keyPath(keyPath)
      self.store = store
    }

    public init(_ key: String) where Value == Bool {
      @Dependency(\.defaultAppStorage) var store
      self._load = { [store] in store.object(forKey: key) as? Value }
      self._save = { [store] in store.set($0, forKey: key) }
      self.key = .string(key)
      self.store = store
    }

    public init(_ key: String) where Value == Int {
      @Dependency(\.defaultAppStorage) var store
      self._load = { [store] in store.object(forKey: key) as? Value }
      self._save = { [store] in store.set($0, forKey: key) }
      self.key = .string(key)
      self.store = store
    }

    public init(_ key: String) where Value == Double {
      @Dependency(\.defaultAppStorage) var store
      self._load = { [store] in store.object(forKey: key) as? Value }
      self._save = { [store] in store.set($0, forKey: key) }
      self.key = .string(key)
      self.store = store
    }

    public init(_ key: String) where Value == String {
      @Dependency(\.defaultAppStorage) var store
      self._load = { [store] in store.object(forKey: key) as? Value }
      self._save = { [store] in store.set($0, forKey: key) }
      self.key = .string(key)
      self.store = store
    }

    public init(_ key: String) where Value == URL {
      @Dependency(\.defaultAppStorage) var store
      self._load = { [store] in store.object(forKey: key) as? Value }
      self._save = { [store] in store.set($0, forKey: key) }
      self.key = .string(key)
      self.store = store
    }

    public init(_ key: String) where Value == Data {
      @Dependency(\.defaultAppStorage) var store
      self._load = { [store] in store.object(forKey: key) as? Value }
      self._save = { [store] in store.set($0, forKey: key) }
      self.key = .string(key)
      self.store = store
    }

    public init(_ key: String)
    where Value: RawRepresentable, Value.RawValue == Int {
      @Dependency(\.defaultAppStorage) var store
      self._load = { [store] in
        (store.object(forKey: key) as? Value.RawValue).flatMap(Value.init(rawValue:))
      }
      self._save = { [store] in store.set($0.rawValue, forKey: key) }
      self.key = .string(key)
      self.store = store
    }

    public init(_ key: String)
    where Value: RawRepresentable, Value.RawValue == String {
      @Dependency(\.defaultAppStorage) var store
      self._load = { [store] in
        (store.object(forKey: key) as? Value.RawValue).flatMap(Value.init(rawValue:))
      }
      self._save = { [store] in store.set($0.rawValue, forKey: key) }
      self.key = .string(key)
      self.store = store
    }

    public init(_ key: String) where Value == Bool? {
      @Dependency(\.defaultAppStorage) var store
      self._load = { [store] in store.object(forKey: key) as? Value }
      self._save = { [store] in store.set($0 ?? nil, forKey: key) }
      self.key = .string(key)
      self.store = store
    }

    public init(_ key: String) where Value == Int? {
      @Dependency(\.defaultAppStorage) var store
      self._load = { [store] in store.object(forKey: key) as? Value }
      self._save = { [store] in store.set($0 ?? nil, forKey: key) }
      self.key = .string(key)
      self.store = store
    }

    public init(_ key: String) where Value == Double? {
      @Dependency(\.defaultAppStorage) var store
      self._load = { [store] in store.object(forKey: key) as? Value }
      self._save = { [store] in store.set($0 ?? nil, forKey: key) }
      self.key = .string(key)
      self.store = store
    }

    public init(_ key: String) where Value == String? {
      @Dependency(\.defaultAppStorage) var store
      self._load = { [store] in store.object(forKey: key) as? Value }
      self._save = { [store] in store.set($0 ?? nil, forKey: key) }
      self.key = .string(key)
      self.store = store
    }

    public init(_ key: String) where Value == URL? {
      @Dependency(\.defaultAppStorage) var store
      self._load = { [store] in store.object(forKey: key) as? Value }
      self._save = { [store] in store.set($0 ?? nil, forKey: key) }
      self.key = .string(key)
      self.store = store
    }

    public init(_ key: String) where Value == Data? {
      @Dependency(\.defaultAppStorage) var store
      self._load = { [store] in store.object(forKey: key) as? Value }
      self._save = { [store] in store.set($0 ?? nil, forKey: key) }
      self.key = .string(key)
      self.store = store
    }

    public init<R: RawRepresentable>(_ key: String)
    where R.RawValue == Int, Value == R? {
      @Dependency(\.defaultAppStorage) var store
      self._load = { [store] in
        (store.object(forKey: key) as? R.RawValue).flatMap(R.init(rawValue:))
      }
      self._save = { [store] in store.set($0?.rawValue, forKey: key) }
      self.key = .string(key)
      self.store = store
    }

    public init<R: RawRepresentable>(_ key: String)
    where R.RawValue == String, Value == R? {
      @Dependency(\.defaultAppStorage) var store
      self._load = { [store] in
        (store.object(forKey: key) as? R.RawValue).flatMap(R.init(rawValue:))
      }
      self._save = { [store] in store.set($0?.rawValue, forKey: key) }
      self.key = .string(key)
      self.store = store
    }
  }

  extension AppStorageKey: PersistenceKey {
    public func load(initialValue: Value?) -> Value? {
      if let initialValue, case let .string(key) = self.key {
        self.store.register(defaults: [key: initialValue])
      }
      return self._load() ?? initialValue
    }

    public func save(_ value: Value) {
      SharedAppStorageLocals.$isSetting.withValue(true) {
        self._save(value)
      }
    }

    public func subscribe(
      initialValue: Value?, didSet: @escaping (_ newValue: Value?) -> Void
    ) -> Shared<Value>.Subscription {
      switch self.key {
      case let .keyPath(key):
        let observer = self.store.observe(key, options: .new) { _, change in
          guard
            !SharedAppStorageLocals.isSetting
          else { return }
          didSet(change.newValue ?? initialValue)
        }
        return Shared.Subscription {
          observer.invalidate()
        }
      case let .string(key):
        let observer = Observer { value in
          guard
            !SharedAppStorageLocals.isSetting
          else { return }
          didSet(value ?? initialValue)
        }
        self.store.addObserver(observer, forKeyPath: key, options: .new, context: nil)
        return Shared.Subscription {
          self.store.removeObserver(observer, forKeyPath: key)
        }
      }
    }

    private class Observer: NSObject {
      let didChange: (Value?) -> Void
      init(didChange: @escaping (Value?) -> Void) {
        self.didChange = didChange
        super.init()
      }
      override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
      ) {
        self.didChange(change?[.newKey] as? Value)
      }
    }
  }

  extension AppStorageKey: Hashable {
    public static func == (lhs: AppStorageKey, rhs: AppStorageKey) -> Bool {
      lhs.key == rhs.key && lhs.store == rhs.store
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(self.key)
      hasher.combine(self.store)
    }
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
#endif
