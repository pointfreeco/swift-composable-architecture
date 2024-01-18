#if canImport(Perception)
  import Foundation

  extension SharedPersistence {
    @available(*, deprecated)
    public static func appStorage<Value: Codable>(
      _ key: String, store: UserDefaults? = nil
    ) -> Self where Self == SharedAppStorage<Value> {
      SharedAppStorage(key, store: store)
    }

    public static func appStorage(_ key: String, store: UserDefaults? = nil) -> Self
    where Self == SharedAppStorage<Bool> {
      SharedAppStorage(key, store: store)
    }

    public static func appStorage(_ key: String, store: UserDefaults? = nil) -> Self
    where Self == SharedAppStorage<Int> {
      SharedAppStorage(key, store: store)
    }

    public static func appStorage(_ key: String, store: UserDefaults? = nil) -> Self
    where Self == SharedAppStorage<Double> {
      SharedAppStorage(key, store: store)
    }

    public static func appStorage(_ key: String, store: UserDefaults? = nil) -> Self
    where Self == SharedAppStorage<String> {
      SharedAppStorage(key, store: store)
    }

    public static func appStorage(_ key: String, store: UserDefaults? = nil) -> Self
    where Self == SharedAppStorage<URL> {
      SharedAppStorage(key, store: store)
    }

    public static func appStorage(_ key: String, store: UserDefaults? = nil) -> Self
    where Self == SharedAppStorage<Data> {
      SharedAppStorage(key, store: store)
    }

    public static func appStorage<Value: RawRepresentable>(
      _ key: String, store: UserDefaults? = nil
    ) -> Self where Value.RawValue == Int, Self == SharedAppStorage<Value> {
      SharedAppStorage(key, store: store)
    }

    public static func appStorage<Value: RawRepresentable>(
      _ key: String, store: UserDefaults? = nil
    ) -> Self where Value.RawValue == String, Self == SharedAppStorage<Value> {
      SharedAppStorage(key, store: store)
    }

    public static func appStorage(_ key: String, store: UserDefaults? = nil) -> Self
    where Self == SharedAppStorage<Bool?> {
      SharedAppStorage(key, store: store)
    }

    public static func appStorage(_ key: String, store: UserDefaults? = nil) -> Self
    where Self == SharedAppStorage<Int?> {
      SharedAppStorage(key, store: store)
    }

    public static func appStorage(_ key: String, store: UserDefaults? = nil) -> Self
    where Self == SharedAppStorage<Double?> {
      SharedAppStorage(key, store: store)
    }

    public static func appStorage(_ key: String, store: UserDefaults? = nil) -> Self
    where Self == SharedAppStorage<String?> {
      SharedAppStorage(key, store: store)
    }

    public static func appStorage(_ key: String, store: UserDefaults? = nil) -> Self
    where Self == SharedAppStorage<URL?> {
      SharedAppStorage(key, store: store)
    }

    public static func appStorage(_ key: String, store: UserDefaults? = nil) -> Self
    where Self == SharedAppStorage<Data?> {
      SharedAppStorage(key, store: store)
    }

    public static func appStorage<Value: RawRepresentable>(
      _ key: String, store: UserDefaults? = nil
    ) -> Self where Value.RawValue == Int, Self == SharedAppStorage<Value?> {
      SharedAppStorage(key, store: store)
    }

    public static func appStorage<Value: RawRepresentable>(
      _ key: String, store: UserDefaults? = nil
    ) -> Self where Value.RawValue == String, Self == SharedAppStorage<Value?> {
      SharedAppStorage(key, store: store)
    }
  }

  public struct SharedAppStorage<Value> {
    private let _get: () -> Value?
    private let _didSet: (Value) -> Void
    private let key: String
    private let store: UserDefaults

    private class Observer: NSObject {
      let didChange: () -> Void
      init(didChange: @escaping () -> Void) {
        self.didChange = didChange
        super.init()
      }
      public override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
      ) {
        self.didChange()
      }
    }

    @available(*, deprecated)
    public init(_ key: String, store: UserDefaults?) where Value: Codable {
      @Dependency(\.userDefaults) var userDefaults
      let store = store ?? userDefaults

      let decoder = JSONDecoder()
      let encoder = JSONEncoder()
      encoder.outputFormatting = .sortedKeys

      self._get = {
        try? store.data(forKey: key).map { try decoder.decode(Value.self, from: $0) }
      }
      self._didSet = {
        let data = try! encoder.encode($0)
        if data != store.data(forKey: key) {
          store.set(data, forKey: key)
        }
      }
      self.key = key
      self.store = store
    }

    public init(_ key: String, store: UserDefaults?) where Value == Bool {
      @Dependency(\.userDefaults) var userDefaults
      let store = store ?? userDefaults
      self._get = { store.object(forKey: key) as? Value }
      self._didSet = { if store.object(forKey: key) as? Value != $0 { store.set($0, forKey: key) } }
      self.key = key
      self.store = store
    }

    public init(_ key: String, store: UserDefaults?) where Value == Int {
      @Dependency(\.userDefaults) var userDefaults
      let store = store ?? userDefaults
      self._get = { store.object(forKey: key) as? Value }
      self._didSet = { if store.object(forKey: key) as? Value != $0 { store.set($0, forKey: key) } }
      self.key = key
      self.store = store
    }

    public init(_ key: String, store: UserDefaults?) where Value == Double {
      @Dependency(\.userDefaults) var userDefaults
      let store = store ?? userDefaults
      self._get = { store.object(forKey: key) as? Value }
      self._didSet = { if store.object(forKey: key) as? Value != $0 { store.set($0, forKey: key) } }
      self.key = key
      self.store = store
    }

    public init(_ key: String, store: UserDefaults?) where Value == String {
      @Dependency(\.userDefaults) var userDefaults
      let store = store ?? userDefaults
      self._get = { store.object(forKey: key) as? Value }
      self._didSet = { if store.object(forKey: key) as? Value != $0 { store.set($0, forKey: key) } }
      self.key = key
      self.store = store
    }

    public init(_ key: String, store: UserDefaults?) where Value == URL {
      @Dependency(\.userDefaults) var userDefaults
      let store = store ?? userDefaults
      self._get = { store.object(forKey: key) as? Value }
      self._didSet = { if store.object(forKey: key) as? Value != $0 { store.set($0, forKey: key) } }
      self.key = key
      self.store = store
    }

    public init(_ key: String, store: UserDefaults?) where Value == Data {
      @Dependency(\.userDefaults) var userDefaults
      let store = store ?? userDefaults
      self._get = { store.object(forKey: key) as? Value }
      self._didSet = { if store.object(forKey: key) as? Value != $0 { store.set($0, forKey: key) } }
      self.key = key
      self.store = store
    }

    public init(_ key: String, store: UserDefaults?)
    where Value: RawRepresentable, Value.RawValue == Int {
      @Dependency(\.userDefaults) var userDefaults
      let store = store ?? userDefaults
      self._get = { (store.object(forKey: key) as? Value.RawValue).flatMap(Value.init(rawValue:)) }
      self._didSet = {
        if store.object(forKey: key) as? Value.RawValue != $0.rawValue {
          store.set($0.rawValue, forKey: key)
        }
      }
      self.key = key
      self.store = store
    }

    public init(_ key: String, store: UserDefaults?)
    where Value: RawRepresentable, Value.RawValue == String {
      @Dependency(\.userDefaults) var userDefaults
      let store = store ?? userDefaults
      self._get = { (store.object(forKey: key) as? Value.RawValue).flatMap(Value.init(rawValue:)) }
      self._didSet = {
        if store.object(forKey: key) as? Value.RawValue != $0.rawValue {
          store.set($0.rawValue, forKey: key)
        }
      }
      self.key = key
      self.store = store
    }

    public init(_ key: String, store: UserDefaults?) where Value == Bool? {
      @Dependency(\.userDefaults) var userDefaults
      let store = store ?? userDefaults
      self._get = { store.object(forKey: key) as? Value }
      self._didSet = { if store.object(forKey: key) as? Value != $0 { store.set($0, forKey: key) } }
      self.key = key
      self.store = store
    }

    public init(_ key: String, store: UserDefaults?) where Value == Int? {
      @Dependency(\.userDefaults) var userDefaults
      let store = store ?? userDefaults
      self._get = { store.object(forKey: key) as? Value }
      self._didSet = { if store.object(forKey: key) as? Value != $0 { store.set($0, forKey: key) } }
      self.key = key
      self.store = store
    }

    public init(_ key: String, store: UserDefaults?) where Value == Double? {
      @Dependency(\.userDefaults) var userDefaults
      let store = store ?? userDefaults
      self._get = { store.object(forKey: key) as? Value }
      self._didSet = { if store.object(forKey: key) as? Value != $0 { store.set($0, forKey: key) } }
      self.key = key
      self.store = store
    }

    public init(_ key: String, store: UserDefaults?) where Value == String? {
      @Dependency(\.userDefaults) var userDefaults
      let store = store ?? userDefaults
      self._get = { store.object(forKey: key) as? Value }
      self._didSet = { if store.object(forKey: key) as? Value != $0 { store.set($0, forKey: key) } }
      self.key = key
      self.store = store
    }

    public init(_ key: String, store: UserDefaults?) where Value == URL? {
      @Dependency(\.userDefaults) var userDefaults
      let store = store ?? userDefaults
      self._get = { store.object(forKey: key) as? Value }
      self._didSet = { if store.object(forKey: key) as? Value != $0 { store.set($0, forKey: key) } }
      self.key = key
      self.store = store
    }

    public init(_ key: String, store: UserDefaults?) where Value == Data? {
      @Dependency(\.userDefaults) var userDefaults
      let store = store ?? userDefaults
      self._get = { store.object(forKey: key) as? Value }
      self._didSet = { if store.object(forKey: key) as? Value != $0 { store.set($0, forKey: key) } }
      self.key = key
      self.store = store
    }

    public init<R: RawRepresentable>(_ key: String, store: UserDefaults?)
    where R.RawValue == Int, Value == R? {
      @Dependency(\.userDefaults) var userDefaults
      let store = store ?? userDefaults
      self._get = { (store.object(forKey: key) as? R.RawValue).flatMap(R.init(rawValue:)) }
      self._didSet = {
        if store.object(forKey: key) as? R.RawValue != $0?.rawValue {
          store.set($0?.rawValue, forKey: key)
        }
      }
      self.key = key
      self.store = store
    }

    public init<R: RawRepresentable>(_ key: String, store: UserDefaults?)
    where R.RawValue == String, Value == R? {
      @Dependency(\.userDefaults) var userDefaults
      let store = store ?? userDefaults
      self._get = { (store.object(forKey: key) as? R.RawValue).flatMap(R.init(rawValue:)) }
      self._didSet = {
        if store.object(forKey: key) as? R.RawValue != $0?.rawValue {
          store.set($0?.rawValue, forKey: key)
        }
      }
      self.key = key
      self.store = store
    }
  }

  extension SharedAppStorage: SharedPersistence {
    public var values: AsyncStream<Value> {
      AsyncStream<Value> { continuation in
        let observer = Observer {
          guard let value = self.get() else {
            return
          }
          continuation.yield(value)
        }
        self.store.addObserver(observer, forKeyPath: self.key, context: nil)
        continuation.onTermination = { _ in
          observer.removeObserver(self.store, forKeyPath: self.key)
        }
      }
    }

    public func get() -> Value? {
      self._get()
    }

    public func didSet(oldValue _: Value, value: Value) {
      self._didSet(value)
    }
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

  private enum UserDefaultsKey: DependencyKey {
    static var testValue: UncheckedSendable<UserDefaults> {
      let userDefaults = UserDefaults(suiteName: "test")!
      userDefaults.removePersistentDomain(forName: "test")
      return UncheckedSendable(userDefaults)
    }
    static var previewValue: UncheckedSendable<UserDefaults> {
      Self.testValue
    }
    static let liveValue = UncheckedSendable(UserDefaults.standard)
  }

  extension DependencyValues {
    public var userDefaults: UserDefaults {
      get { self[UserDefaultsKey.self].value }
      set { self[UserDefaultsKey.self].value = newValue }
    }
  }
#endif
