import Dependencies
import Foundation

#if canImport(Combine)
  import Combine
#endif

extension Shared {
  /// Creates a shared reference to a value using a persistence key.
  ///
  /// - Parameters:
  ///   - value: A default value that is used when no value can be returned from the persistence
  ///     key.
  ///   - persistenceKey: A persistence key associated with the shared reference. It is responsible
  ///     for loading and saving the shared reference's value from some external source.
  public init(
    wrappedValue value: @autoclosure @Sendable () -> Value,
    _ persistenceKey: some PersistenceKey<Value>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.init(throwingValue: value(), persistenceKey, fileID: fileID, line: line)
  }

  /// Creates a shared reference to an optional value using a persistence key.
  ///
  /// - Parameters:
  ///   - persistenceKey: A persistence key associated with the shared reference. It is responsible
  ///     for loading and saving the shared reference's value from some external source.
  @_disfavoredOverload
  public init<Wrapped>(
    _ persistenceKey: some PersistenceKey<Value>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) where Value == Wrapped? {
    self.init(wrappedValue: nil, persistenceKey, fileID: fileID, line: line)
  }

  /// Creates a shared reference to a value using a persistence key.
  ///
  /// If the given persistence key cannot load a value, an error is thrown. For a non-throwing
  /// version of this initializer, see ``init(wrappedValue:_:fileID:line:)-512rh``.
  ///
  /// - Parameters:
  ///   - persistenceKey: A persistence key associated with the shared reference. It is responsible
  ///     for loading and saving the shared reference's value from some external source.
  @_disfavoredOverload
  public init(
    _ persistenceKey: some PersistenceKey<Value>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) throws {
    try self.init(
      throwingValue: {
        guard let initialValue = persistenceKey.load(initialValue: nil)
        else { throw LoadError() }
        return initialValue
      }(),
      persistenceKey,
      fileID: fileID,
      line: line
    )
  }

  private init(
    throwingValue value: @autoclosure @Sendable () throws -> Value,
    _ persistenceKey: some PersistenceKey<Value>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) rethrows {
    let id = AnyHashableSendable(persistenceKey.id)
    @Dependency(\.persistentReferences) var references
    guard let reference = references[id] else {
      let value = try value()
      let reference = references[
        id,
        default: ValueReference(
          initialValue: value,
          persistenceKey: persistenceKey,
          fileID: fileID,
          line: line
        )
      ]
      self.init(reference: reference, keyPath: \Value.self)
      return
    }
    self.init(reference: reference, keyPath: \Value.self)
  }

  /// Creates a shared reference to a value using a persistence key with a default value.
  ///
  /// - Parameters:
  ///   - persistenceKey: A persistence key associated with the shared reference. It is responsible
  ///     for loading and saving the shared reference's value from some external source.
  public init<Key: PersistenceKey<Value>>(
    _ persistenceKey: PersistenceKeyDefault<Key>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.init(
      wrappedValue: persistenceKey.defaultValue(),
      persistenceKey.base,
      fileID: fileID,
      line: line
    )
  }

  /// Creates a shared reference to a value using a persistence key by overriding its default value.
  ///
  /// - Parameters:
  ///   - value: A default value that is used when no value can be returned from the persistence
  ///     key.
  ///   - persistenceKey: A persistence key associated with the shared reference. It is responsible
  ///     for loading and saving the shared reference's value from some external source.
  public init<Key: PersistenceKey<Value>>(
    wrappedValue value: @autoclosure @Sendable () -> Value,
    _ persistenceKey: PersistenceKeyDefault<Key>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.init(
      wrappedValue: value(),
      persistenceKey.base,
      fileID: fileID,
      line: line
    )
  }
}

extension SharedReader {
  /// Creates a shared reference to a read-only value using a persistence key.
  ///
  /// - Parameters:
  ///   - value: A default value that is used when no value can be returned from the persistence
  ///     key.
  ///   - persistenceKey: A persistence key associated with the shared reference. It is responsible
  ///     for loading the shared reference's value from some external source.
  public init(
    wrappedValue value: @autoclosure @Sendable () -> Value,
    _ persistenceKey: some PersistenceReaderKey<Value>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.init(
      throwingValue: value(),
      persistenceKey,
      fileID: fileID,
      line: line
    )
  }

  /// Creates a shared reference to an optional, read-only value using a persistence key.
  ///
  /// - Parameters:
  ///   - persistenceKey: A persistence key associated with the shared reference. It is responsible
  ///     for loading the shared reference's value from some external source.
  @_disfavoredOverload
  public init<Wrapped>(
    _ persistenceKey: some PersistenceReaderKey<Value>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) where Value == Wrapped? {
    self.init(wrappedValue: nil, persistenceKey, fileID: fileID, line: line)
  }

  /// Creates a shared reference to a read-only value using a persistence key.
  ///
  /// If the given persistence key cannot load a value, an error is thrown. For a non-throwing
  /// version of this initializer, see ``init(wrappedValue:_:fileID:line:)-7q52``.
  ///
  /// - Parameters:
  ///   - persistenceKey: A persistence key associated with the shared reference. It is responsible
  ///     for loading the shared reference's value from some external source.
  @_disfavoredOverload
  public init(
    _ persistenceKey: some PersistenceReaderKey<Value>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) throws {
    try self.init(
      throwingValue: {
        guard let initialValue = persistenceKey.load(initialValue: nil)
        else { throw LoadError() }
        return initialValue
      }(),
      persistenceKey,
      fileID: fileID,
      line: line
    )
  }

  private init(
    throwingValue value: @autoclosure @Sendable () throws -> Value,
    _ persistenceKey: some PersistenceReaderKey<Value>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) rethrows {
    let id = AnyHashableSendable(persistenceKey.id)
    @Dependency(\.persistentReferences) var references
    guard let reference = references[id] else {
      let value = try value()
      let reference = references[
        id,
        default: ValueReference(
          initialValue: value,
          persistenceKey: persistenceKey,
          fileID: fileID,
          line: line
        )
      ]
      self.init(reference: reference, keyPath: \Value.self)
      return
    }
    self.init(reference: reference, keyPath: \Value.self)
  }

  /// Creates a shared reference to a read-only value using a persistence key with a default value.
  ///
  /// - Parameters:
  ///   - persistenceKey: A persistence key associated with the shared reference. It is responsible
  ///     for loading the shared reference's value from some external source.
  public init<Key: PersistenceReaderKey<Value>>(
    _ persistenceKey: PersistenceKeyDefault<Key>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.init(
      wrappedValue: persistenceKey.defaultValue(),
      persistenceKey.base,
      fileID: fileID,
      line: line
    )
  }

  /// Creates a shared reference to a value using a persistence key by overriding its default value.
  ///
  /// - Parameters:
  ///   - value: A default value that is used when no value can be returned from the persistence
  ///     key.
  ///   - persistenceKey: A persistence key associated with the shared reference. It is responsible
  ///     for loading the shared reference's value from some external source.
  public init<Key: PersistenceReaderKey<Value>>(
    wrappedValue value: @autoclosure @Sendable () -> Value,
    _ persistenceKey: PersistenceKeyDefault<Key>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.init(
      wrappedValue: value(),
      persistenceKey.base,
      fileID: fileID,
      line: line
    )
  }
}

private struct LoadError: Error {}

final class ValueReference<Value, Persistence: PersistenceReaderKey<Value>>: Reference,
  @unchecked Sendable
{
  private let lock = NSRecursiveLock()
  private let persistenceKey: Persistence?
  #if canImport(Combine)
    private let subject: CurrentValueRelay<Value>
  #endif
  private var subscription: Shared<Value>.Subscription!
  private var _value: Value {
    willSet {
      self.subject.send(newValue)
    }
  }
  private let _$perceptionRegistrar = PerceptionRegistrar(
    isPerceptionCheckingEnabled: _isStorePerceptionCheckingEnabled
  )
  private let fileID: StaticString
  private let line: UInt
  var value: Value {
    get {
      self._$perceptionRegistrar.access(self, keyPath: \.value)
      return self.lock.withLock { self._value }
    }
    set {
      self._$perceptionRegistrar.willSet(self, keyPath: \.value)
      defer { self._$perceptionRegistrar.didSet(self, keyPath: \.value) }
      self.lock.withLock {
        self._value = newValue
        func open<A>(_ key: some PersistenceKey<A>) {
          key.save(self._value as! A)
        }
        guard let key = self.persistenceKey as? any PersistenceKey
        else { return }
        open(key)
      }
    }
  }
  #if canImport(Combine)
    var publisher: AnyPublisher<Value, Never> {
      self.subject.dropFirst().eraseToAnyPublisher()
    }
  #endif
  init(
    initialValue: Value,
    persistenceKey: Persistence? = nil,
    fileID: StaticString,
    line: UInt
  ) {
    self._value = persistenceKey?.load(initialValue: initialValue) ?? initialValue
    self.persistenceKey = persistenceKey
    #if canImport(Combine)
      self.subject = CurrentValueRelay(initialValue)
    #endif
    self.fileID = fileID
    self.line = line
    if let persistenceKey {
      self.subscription = persistenceKey.subscribe(
        initialValue: initialValue
      ) { [weak self] value in
        guard let self else { return }
        mainActorASAP {
          self._$perceptionRegistrar.willSet(self, keyPath: \.value)
          defer { self._$perceptionRegistrar.didSet(self, keyPath: \.value) }
          self.lock.withLock {
            self._value = value ?? initialValue
          }
        }
      }
    }
  }
  func access() {
    _$perceptionRegistrar.access(self, keyPath: \.value)
  }
  func withMutation<T>(_ mutation: () throws -> T) rethrows -> T {
    self._$perceptionRegistrar.willSet(self, keyPath: \.value)
    defer { self._$perceptionRegistrar.didSet(self, keyPath: \.value) }
    return try mutation()
  }
  var description: String {
    "Shared<\(Value.self)>@\(self.fileID):\(self.line)"
  }
}

#if canImport(Observation)
  extension ValueReference: Observable {}
#endif

extension ValueReference: Perceptible {}

private enum PersistentReferencesKey: DependencyKey {
  static var liveValue: ManagedDictionary<AnyHashableSendable, any Reference> {
    ManagedDictionary()
  }
  static var testValue: ManagedDictionary<AnyHashableSendable, any Reference> {
    ManagedDictionary()
  }
}

extension DependencyValues {
  var persistentReferences: ManagedDictionary<AnyHashableSendable, any Reference> {
    self[PersistentReferencesKey.self]
  }
}

struct Managed<Value>: Sendable {
  fileprivate let storage: any ManagedStorage<Value>
  var value: Value {
    storage.wrappedValue
  }
}

extension Managed where Value: Sendable {
  init(_ value: Value) {
    self.init(storage: UnmanagedStorage(wrappedValue: value))
  }
}

private struct UnmanagedStorage<Value: Sendable>: ManagedStorage, Sendable {
  var wrappedValue: Value
}

private protocol ManagedStorage<Value>: Sendable {
  associatedtype Value
  var wrappedValue: Value { get }
}

struct ManagedDictionary<Key: Hashable & Sendable, Value> {
  private let storage = Storage()

  subscript(key: Key) -> Managed<Value>? {
    guard let reference = storage.withLock({ $0[key] }) else { return nil }
    let storage = ManagedValue(
      key: key,
      value: reference.value,
      storage: storage,
      counter: reference.counter
    )
    return Managed(storage: storage)
  }

  subscript(key: Key, default value: @autoclosure () -> Value) -> Managed<Value> {
    let reference = storage.withLock { $0[key, default: Reference(value())].touch() }
    let storage = ManagedValue(
      key: key,
      value: reference.value,
      storage: storage,
      counter: reference.counter
    )
    return Managed(storage: storage)
  }

  fileprivate final class ReferenceCounter: @unchecked Sendable {
    private var count = 0
    private let lock = NSLock()
    @discardableResult
    func increment() -> Int {
      lock.withLock {
        count += 1
        return count
      }
    }
    @discardableResult
    func decrement() -> Int {
      lock.withLock {
        count -= 1
        return count
      }
    }
  }

  fileprivate struct Reference {
    let counter = ReferenceCounter()
    let value: Value
    init(_ value: Value) {
      self.value = value
    }
    mutating func touch() -> Self { self }
  }

  private final class Storage: @unchecked Sendable {
    private var dictionary: [Key: Reference] = [:]
    private let lock = NSLock()
    func withLock<R>(_ body: (inout [Key: Reference]) -> R) -> R {
      lock.withLock {
        body(&dictionary)
      }
    }
  }

  private final class ManagedValue: ManagedStorage, @unchecked Sendable {
    let key: Key
    let wrappedValue: Value
    let counter: ReferenceCounter
    weak var storage: Storage?

    fileprivate init(
      key: Key,
      value: Value,
      storage: Storage,
      counter: ReferenceCounter
    ) {
      self.key = key
      self.wrappedValue = value
      self.storage = storage
      self.counter = counter
      let count = counter.increment()
      precondition(count > 0)
    }

    deinit {
      guard let storage, counter.decrement() <= 0 else { return }
      storage.withLock { $0[key] = nil }
    }
  }
}
