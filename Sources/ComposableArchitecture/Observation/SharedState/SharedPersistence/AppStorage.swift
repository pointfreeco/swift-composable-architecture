#if canImport(Perception)
  import Foundation

  extension SharedPersistence {
    public static func appStorage(_ key: String) -> Self
    where Self == SharedAppStorage<Bool> {
      SharedAppStorage(key)
    }

    public static func appStorage(_ key: String) -> Self
    where Self == SharedAppStorage<Int> {
      SharedAppStorage(key)
    }

    public static func appStorage(_ key: String) -> Self
    where Self == SharedAppStorage<Double> {
      SharedAppStorage(key)
    }

    public static func appStorage(_ key: String) -> Self
    where Self == SharedAppStorage<String> {
      SharedAppStorage(key)
    }

    public static func appStorage(_ key: String) -> Self
    where Self == SharedAppStorage<URL> {
      SharedAppStorage(key)
    }

    public static func appStorage(_ key: String) -> Self
    where Self == SharedAppStorage<Data> {
      SharedAppStorage(key)
    }

    public static func appStorage<Value: RawRepresentable>(_ key: String) -> Self
    where Value.RawValue == Int, Self == SharedAppStorage<Value> {
      SharedAppStorage(key)
    }

    public static func appStorage<Value: RawRepresentable>(_ key: String) -> Self
    where Value.RawValue == String, Self == SharedAppStorage<Value> {
      SharedAppStorage(key)
    }

    public static func appStorage(_ key: String) -> Self
    where Self == SharedAppStorage<Bool?> {
      SharedAppStorage(key)
    }

    public static func appStorage(_ key: String) -> Self
    where Self == SharedAppStorage<Int?> {
      SharedAppStorage(key)
    }

    public static func appStorage(_ key: String) -> Self
    where Self == SharedAppStorage<Double?> {
      SharedAppStorage(key)
    }

    public static func appStorage(_ key: String) -> Self
    where Self == SharedAppStorage<String?> {
      SharedAppStorage(key)
    }

    public static func appStorage(_ key: String) -> Self
    where Self == SharedAppStorage<URL?> {
      SharedAppStorage(key)
    }

    public static func appStorage(_ key: String) -> Self
    where Self == SharedAppStorage<Data?> {
      SharedAppStorage(key)
    }

    public static func appStorage<Value: RawRepresentable>(_ key: String) -> Self
    where Value.RawValue == Int, Self == SharedAppStorage<Value?> {
      SharedAppStorage(key)
    }

    public static func appStorage<Value: RawRepresentable>(_ key: String) -> Self
    where Value.RawValue == String, Self == SharedAppStorage<Value?> {
      SharedAppStorage(key)
    }
  }

  public struct SharedAppStorage<Value> {
    private let _get: () -> Value?
    private let _didSet: (Value) -> Void
    private let key: String
    private let store: UserDefaults

    @available(*, deprecated)
    public init(_ key: String) where Value: Codable {
      @Dependency(\.defaultAppStorage) var store

      let decoder = JSONDecoder()
      let encoder = JSONEncoder()

      self._get = { try? store.data(forKey: key).map { try decoder.decode(Value.self, from: $0) } }
      self._didSet = { store.set(try! encoder.encode($0), forKey: key) }
      self.key = key
      self.store = store
    }

    public init(_ key: String) where Value == Bool {
      @Dependency(\.defaultAppStorage) var store
      self._get = { store.object(forKey: key) as? Value }
      self._didSet = { store.set($0, forKey: key) }
      self.key = key
      self.store = store
    }

    public init(_ key: String) where Value == Int {
      @Dependency(\.defaultAppStorage) var store
      self._get = { store.object(forKey: key) as? Value }
      self._didSet = { store.set($0, forKey: key) }
      self.key = key
      self.store = store
    }

    public init(_ key: String) where Value == Double {
      @Dependency(\.defaultAppStorage) var store
      self._get = { store.object(forKey: key) as? Value }
      self._didSet = { store.set($0, forKey: key) }
      self.key = key
      self.store = store
    }

    public init(_ key: String) where Value == String {
      @Dependency(\.defaultAppStorage) var store
      self._get = { store.object(forKey: key) as? Value }
      self._didSet = { store.set($0, forKey: key) }
      self.key = key
      self.store = store
    }

    public init(_ key: String) where Value == URL {
      @Dependency(\.defaultAppStorage) var store
      self._get = { store.object(forKey: key) as? Value }
      self._didSet = { store.set($0, forKey: key) }
      self.key = key
      self.store = store
    }

    public init(_ key: String) where Value == Data {
      @Dependency(\.defaultAppStorage) var store
      self._get = { store.object(forKey: key) as? Value }
      self._didSet = { store.set($0, forKey: key) }
      self.key = key
      self.store = store
    }

    public init(_ key: String)
    where Value: RawRepresentable, Value.RawValue == Int {
      @Dependency(\.defaultAppStorage) var store
      self._get = { (store.object(forKey: key) as? Value.RawValue).flatMap(Value.init(rawValue:)) }
      self._didSet = { store.set($0.rawValue, forKey: key) }
      self.key = key
      self.store = store
    }

    public init(_ key: String)
    where Value: RawRepresentable, Value.RawValue == String {
      @Dependency(\.defaultAppStorage) var store
      self._get = { (store.object(forKey: key) as? Value.RawValue).flatMap(Value.init(rawValue:)) }
      self._didSet = { store.set($0.rawValue, forKey: key) }
      self.key = key
      self.store = store
    }

    public init(_ key: String) where Value == Bool? {
      @Dependency(\.defaultAppStorage) var store
      self._get = { store.object(forKey: key) as? Value }
      self._didSet = { store.set($0, forKey: key) }
      self.key = key
      self.store = store
    }

    public init(_ key: String) where Value == Int? {
      @Dependency(\.defaultAppStorage) var store
      self._get = { store.object(forKey: key) as? Value }
      self._didSet = { store.set($0, forKey: key) }
      self.key = key
      self.store = store
    }

    public init(_ key: String) where Value == Double? {
      @Dependency(\.defaultAppStorage) var store
      self._get = { store.object(forKey: key) as? Value }
      self._didSet = { store.set($0, forKey: key) }
      self.key = key
      self.store = store
    }

    public init(_ key: String) where Value == String? {
      @Dependency(\.defaultAppStorage) var store
      self._get = { store.object(forKey: key) as? Value }
      self._didSet = { store.set($0, forKey: key) }
      self.key = key
      self.store = store
    }

    public init(_ key: String) where Value == URL? {
      @Dependency(\.defaultAppStorage) var store
      self._get = { store.object(forKey: key) as? Value }
      self._didSet = { store.set($0, forKey: key) }
      self.key = key
      self.store = store
    }

    public init(_ key: String) where Value == Data? {
      @Dependency(\.defaultAppStorage) var store
      self._get = { store.object(forKey: key) as? Value }
      self._didSet = { store.set($0, forKey: key) }
      self.key = key
      self.store = store
    }

    public init<R: RawRepresentable>(_ key: String)
    where R.RawValue == Int, Value == R? {
      @Dependency(\.defaultAppStorage) var store
      self._get = { (store.object(forKey: key) as? R.RawValue).flatMap(R.init(rawValue:)) }
      self._didSet = { store.set($0?.rawValue, forKey: key)  }
      self.key = key
      self.store = store
    }

    public init<R: RawRepresentable>(_ key: String)
    where R.RawValue == String, Value == R? {
      @Dependency(\.defaultAppStorage) var store
      self._get = { (store.object(forKey: key) as? R.RawValue).flatMap(R.init(rawValue:)) }
      self._didSet = { store.set($0?.rawValue, forKey: key) }
      self.key = key
      self.store = store
    }
  }

  extension SharedAppStorage: SharedPersistence {
    public var values: AsyncStream<Value> {
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

    public func get() -> Value? {
      self._get()
    }

    public func didSet(oldValue _: Value, value: Value) {
      SharedAppStorageLocals.$isSetting.withValue(true) {
        self._didSet(value)
      }
    }

    private class Observer: NSObject {
      let didChange: (Value) -> Void
      init(didChange: @escaping (Value) -> Void) {
        self.didChange = didChange
        super.init()
      }
      public override func observeValue(
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

  private enum SharedAppStorageLocals {
    @TaskLocal static var isSetting = false
  }

  extension SharedAppStorage: Hashable {
    public static func == (lhs: SharedAppStorage, rhs: SharedAppStorage) -> Bool {
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
      let defaultAppStorage = UserDefaults(suiteName: "test")!
      defaultAppStorage.removePersistentDomain(forName: "test")
      return UncheckedSendable(defaultAppStorage)
    }
    static var previewValue: UncheckedSendable<UserDefaults> {
      DefaultAppStorageKey.testValue
    }
    static let liveValue = UncheckedSendable(UserDefaults.standard)
  }
#endif
