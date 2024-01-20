#if canImport(Perception)
  import Foundation

  extension SharedPersistence {
    public static func appStorage(_ key: String) -> Self
    where Self == _SharedAppStorage<Bool> {
      _SharedAppStorage(key)
    }

    public static func appStorage(_ key: String) -> Self
    where Self == _SharedAppStorage<Int> {
      _SharedAppStorage(key)
    }

    public static func appStorage(_ key: String) -> Self
    where Self == _SharedAppStorage<Double> {
      _SharedAppStorage(key)
    }

    public static func appStorage(_ key: String) -> Self
    where Self == _SharedAppStorage<String> {
      _SharedAppStorage(key)
    }

    public static func appStorage(_ key: String) -> Self
    where Self == _SharedAppStorage<URL> {
      _SharedAppStorage(key)
    }

    public static func appStorage(_ key: String) -> Self
    where Self == _SharedAppStorage<Data> {
      _SharedAppStorage(key)
    }

    public static func appStorage<Value: RawRepresentable>(_ key: String) -> Self
    where Value.RawValue == Int, Self == _SharedAppStorage<Value> {
      _SharedAppStorage(key)
    }

    public static func appStorage<Value: RawRepresentable>(_ key: String) -> Self
    where Value.RawValue == String, Self == _SharedAppStorage<Value> {
      _SharedAppStorage(key)
    }

    public static func appStorage(_ key: String) -> Self
    where Self == _SharedAppStorage<Bool?> {
      _SharedAppStorage(key)
    }

    public static func appStorage(_ key: String) -> Self
    where Self == _SharedAppStorage<Int?> {
      _SharedAppStorage(key)
    }

    public static func appStorage(_ key: String) -> Self
    where Self == _SharedAppStorage<Double?> {
      _SharedAppStorage(key)
    }

    public static func appStorage(_ key: String) -> Self
    where Self == _SharedAppStorage<String?> {
      _SharedAppStorage(key)
    }

    public static func appStorage(_ key: String) -> Self
    where Self == _SharedAppStorage<URL?> {
      _SharedAppStorage(key)
    }

    public static func appStorage(_ key: String) -> Self
    where Self == _SharedAppStorage<Data?> {
      _SharedAppStorage(key)
    }

    public static func appStorage<Value: RawRepresentable>(_ key: String) -> Self
    where Value.RawValue == Int, Self == _SharedAppStorage<Value?> {
      _SharedAppStorage(key)
    }

    public static func appStorage<Value: RawRepresentable>(_ key: String) -> Self
    where Value.RawValue == String, Self == _SharedAppStorage<Value?> {
      _SharedAppStorage(key)
    }
  }

  public struct _SharedAppStorage<Value> {
    private let _load: () -> Value?
    private let _save: (Value) -> Void
    private let key: String
    private let store: UserDefaults

    public init(_ key: String) where Value == Bool {
      @Dependency(\.defaultAppStorage) var store
      self._load = { store.object(forKey: key) as? Value }
      self._save = { store.set($0, forKey: key) }
      self.key = key
      self.store = store
    }

    public init(_ key: String) where Value == Int {
      @Dependency(\.defaultAppStorage) var store
      self._load = { store.object(forKey: key) as? Value }
      self._save = { store.set($0, forKey: key) }
      self.key = key
      self.store = store
    }

    public init(_ key: String) where Value == Double {
      @Dependency(\.defaultAppStorage) var store
      self._load = { store.object(forKey: key) as? Value }
      self._save = { store.set($0, forKey: key) }
      self.key = key
      self.store = store
    }

    public init(_ key: String) where Value == String {
      @Dependency(\.defaultAppStorage) var store
      self._load = { store.object(forKey: key) as? Value }
      self._save = { store.set($0, forKey: key) }
      self.key = key
      self.store = store
    }

    public init(_ key: String) where Value == URL {
      @Dependency(\.defaultAppStorage) var store
      self._load = { store.object(forKey: key) as? Value }
      self._save = { store.set($0, forKey: key) }
      self.key = key
      self.store = store
    }

    public init(_ key: String) where Value == Data {
      @Dependency(\.defaultAppStorage) var store
      self._load = { store.object(forKey: key) as? Value }
      self._save = { store.set($0, forKey: key) }
      self.key = key
      self.store = store
    }

    public init(_ key: String)
    where Value: RawRepresentable, Value.RawValue == Int {
      @Dependency(\.defaultAppStorage) var store
      self._load = { (store.object(forKey: key) as? Value.RawValue).flatMap(Value.init(rawValue:)) }
      self._save = { store.set($0.rawValue, forKey: key) }
      self.key = key
      self.store = store
    }

    public init(_ key: String)
    where Value: RawRepresentable, Value.RawValue == String {
      @Dependency(\.defaultAppStorage) var store
      self._load = { (store.object(forKey: key) as? Value.RawValue).flatMap(Value.init(rawValue:)) }
      self._save = { store.set($0.rawValue, forKey: key) }
      self.key = key
      self.store = store
    }

    public init(_ key: String) where Value == Bool? {
      @Dependency(\.defaultAppStorage) var store
      self._load = { store.object(forKey: key) as? Value }
      self._save = { store.set($0, forKey: key) }
      self.key = key
      self.store = store
    }

    public init(_ key: String) where Value == Int? {
      @Dependency(\.defaultAppStorage) var store
      self._load = { store.object(forKey: key) as? Value }
      self._save = { store.set($0, forKey: key) }
      self.key = key
      self.store = store
    }

    public init(_ key: String) where Value == Double? {
      @Dependency(\.defaultAppStorage) var store
      self._load = { store.object(forKey: key) as? Value }
      self._save = { store.set($0, forKey: key) }
      self.key = key
      self.store = store
    }

    public init(_ key: String) where Value == String? {
      @Dependency(\.defaultAppStorage) var store
      self._load = { store.object(forKey: key) as? Value }
      self._save = { store.set($0, forKey: key) }
      self.key = key
      self.store = store
    }

    public init(_ key: String) where Value == URL? {
      @Dependency(\.defaultAppStorage) var store
      self._load = { store.object(forKey: key) as? Value }
      self._save = { store.set($0, forKey: key) }
      self.key = key
      self.store = store
    }

    public init(_ key: String) where Value == Data? {
      @Dependency(\.defaultAppStorage) var store
      self._load = { store.object(forKey: key) as? Value }
      self._save = { store.set($0, forKey: key) }
      self.key = key
      self.store = store
    }

    public init<R: RawRepresentable>(_ key: String)
    where R.RawValue == Int, Value == R? {
      @Dependency(\.defaultAppStorage) var store
      self._load = { (store.object(forKey: key) as? R.RawValue).flatMap(R.init(rawValue:)) }
      self._save = { store.set($0?.rawValue, forKey: key)  }
      self.key = key
      self.store = store
    }

    public init<R: RawRepresentable>(_ key: String)
    where R.RawValue == String, Value == R? {
      @Dependency(\.defaultAppStorage) var store
      self._load = { (store.object(forKey: key) as? R.RawValue).flatMap(R.init(rawValue:)) }
      self._save = { store.set($0?.rawValue, forKey: key) }
      self.key = key
      self.store = store
    }
  }

  extension _SharedAppStorage: SharedPersistence {
    public var updates: AsyncStream<Value> {
      AsyncStream<Value> { continuation in
        let observer = Observer { value in
          continuation.yield(value)
        }
        self.store.addObserver(observer, forKeyPath: self.key, options: .new, context: nil)
        continuation.onTermination = { _ in
          observer.removeObserver(self.store, forKeyPath: self.key)
        }
      }
    }

    public func load() -> Value? {
      self._load()
    }

    public func save(_ value: Value) {
      SharedAppStorageLocals.$isSetting.withValue(true) {
        self._save(value)
      }
    }

    private class Observer: NSObject {
      let didChange: (Value) -> Void
      init(didChange: @escaping (Value) -> Void) {
        self.didChange = didChange
        super.init()
      }
      override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
      ) {
        guard 
          !SharedAppStorageLocals.isSetting,
          let new = change?[.newKey] as? Value
        else { return }
        self.didChange(new)
      }
    }
  }

  extension _SharedAppStorage: Hashable {
    public static func == (lhs: _SharedAppStorage, rhs: _SharedAppStorage) -> Bool {
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
      let suiteName = "co.pointfree.ComposableArchitecture.tests"
      let defaultAppStorage = UserDefaults(suiteName: suiteName)!
      defaultAppStorage.removePersistentDomain(forName: suiteName)
      return UncheckedSendable(defaultAppStorage)
    }
    static var previewValue: UncheckedSendable<UserDefaults> {
      DefaultAppStorageKey.testValue
    }
    static var liveValue: UncheckedSendable<UserDefaults> {
      UncheckedSendable(UserDefaults.standard)
    }
  }

  private enum SharedAppStorageLocals {
    @TaskLocal static var isSetting = false
  }
#endif
