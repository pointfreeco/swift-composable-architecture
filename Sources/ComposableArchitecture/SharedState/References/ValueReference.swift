import Dependencies
import Foundation

#if canImport(Combine)
  import Combine
#endif
#if canImport(Perception)
  import Perception
#endif

extension Shared {
  public init(
    wrappedValue value: Value,
    _ persistenceKey: some PersistenceKey<Value>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.init(
      reference: {
        @Dependency(\.persistentReferences) var references
        return references.withValue {
          if let reference = $0[persistenceKey] {
            return reference
          } else {
            let reference = ValueReference(
              initialValue: value,
              persistenceKey: persistenceKey,
              fileID: fileID,
              line: line
            )
            $0[persistenceKey] = reference
            return reference
          }
        }
      }(),
      keyPath: \Value.self
    )
  }

  @_disfavoredOverload
  public init<Wrapped>(
    _ persistenceKey: some PersistenceKey<Value>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) where Value == Wrapped? {
    self.init(wrappedValue: nil, persistenceKey, fileID: fileID, line: line)
  }

  @_disfavoredOverload
  public init(
    _ persistenceKey: some PersistenceKey<Value>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) throws {
    guard let initialValue = persistenceKey.load(initialValue: nil)
    else {
      throw LoadError()
    }
    self.init(wrappedValue: initialValue, persistenceKey, fileID: fileID, line: line)
  }

  public init<Key: PersistenceKey>(
    _ persistenceKey: PersistenceKeyDefault<Key>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) where Key.Value == Value {
    self.init(
      wrappedValue: persistenceKey.load(initialValue: nil) ?? persistenceKey.defaultValue,
      persistenceKey.base,
      fileID: fileID,
      line: line
    )
  }

  public init<Key: PersistenceKey>(
    wrappedValue: Value,
    _ persistenceKey: PersistenceKeyDefault<Key>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) where Key.Value == Value {
    self.init(
      wrappedValue: wrappedValue,
      persistenceKey.base,
      fileID: fileID,
      line: line
    )
  }
}

extension SharedReader {
  public init(
    wrappedValue value: Value,
    _ persistenceKey: some PersistenceReaderKey<Value>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.init(
      reference: {
        @Dependency(\.persistentReferences) var references
        return references.withValue {
          if let reference = $0[persistenceKey] {
            return reference
          } else {
            let reference = ValueReference(
              initialValue: value,
              persistenceKey: persistenceKey,
              fileID: fileID,
              line: line
            )
            $0[persistenceKey] = reference
            return reference
          }
        }
      }(),
      keyPath: \Value.self
    )
  }

  @_disfavoredOverload
  public init<Wrapped>(
    _ persistenceKey: some PersistenceReaderKey<Value>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) where Value == Wrapped? {
    self.init(wrappedValue: nil, persistenceKey, fileID: fileID, line: line)
  }

  @_disfavoredOverload
  public init(
    _ persistenceKey: some PersistenceReaderKey<Value>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) throws {
    guard let initialValue = persistenceKey.load(initialValue: nil)
    else {
      throw LoadError()
    }
    self.init(wrappedValue: initialValue, persistenceKey, fileID: fileID, line: line)
  }

  public init<Key: PersistenceReaderKey>(
    _ persistenceKey: PersistenceKeyDefault<Key>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) where Key.Value == Value {
    self.init(
      wrappedValue: persistenceKey.load(initialValue: nil) ?? persistenceKey.defaultValue,
      persistenceKey.base,
      fileID: fileID,
      line: line
    )
  }

  public init<Key: PersistenceReaderKey>(
    wrappedValue: Value,
    _ persistenceKey: PersistenceKeyDefault<Key>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) where Key.Value == Value {
    self.init(
      wrappedValue: wrappedValue,
      persistenceKey.base,
      fileID: fileID,
      line: line
    )
  }
}

private struct LoadError: Error {}

final class ValueReference<Value, Persistence: PersistenceReaderKey<Value>>: Reference, @unchecked
  Sendable
{
  private let lock = NSRecursiveLock()
  private let persistenceKey: Persistence?
  #if canImport(Combine)
    private let subject: CurrentValueRelay<Value>
  #endif
  private var subscription: Shared<Value>.Subscription?
  private var _value: Value {
    willSet {
      self.subject.send(newValue)
    }
  }
  #if canImport(Perception)
    private let _$perceptionRegistrar = PerceptionRegistrar(
      isPerceptionCheckingEnabled: _isStorePerceptionCheckingEnabled
    )
  #endif
  private let fileID: StaticString
  private let line: UInt
  var value: Value {
    get {
      #if canImport(Perception)
        self._$perceptionRegistrar.access(self, keyPath: \.value)
      #endif
      return self.lock.withLock { self._value }
    }
    set {
      #if canImport(Perception)
        self._$perceptionRegistrar.willSet(self, keyPath: \.value)
        defer { self._$perceptionRegistrar.didSet(self, keyPath: \.value) }
      #endif
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
        #if canImport(Perception)
          self._$perceptionRegistrar.willSet(self, keyPath: \.value)
          defer { self._$perceptionRegistrar.didSet(self, keyPath: \.value) }
        #endif
        self.lock.withLock {
          self._value = value ?? initialValue
        }
      }
    }
  }
  func access() {
    #if canImport(Perception)
      _$perceptionRegistrar.access(self, keyPath: \.value)
    #endif
  }
  func withMutation<T>(_ mutation: () throws -> T) rethrows -> T {
    #if canImport(Perception)
      self._$perceptionRegistrar.willSet(self, keyPath: \.value)
      defer { self._$perceptionRegistrar.didSet(self, keyPath: \.value) }
    #endif
    return try mutation()
  }
  var description: String {
    "Shared<\(Value.self)>@\(self.fileID):\(self.line)"
  }
}

#if canImport(Observation)
  extension ValueReference: Observable {}
#endif
#if canImport(Perception)
  extension ValueReference: Perceptible {}
#endif

private enum PersistentReferencesKey: DependencyKey {
  static var liveValue: LockIsolated<[AnyHashable: any Reference]> {
    LockIsolated([:])
  }
  static var testValue: LockIsolated<[AnyHashable: any Reference]> {
    LockIsolated([:])
  }
}

extension DependencyValues {
  var persistentReferences: LockIsolated<[AnyHashable: any Reference]> {
    get { self[PersistentReferencesKey.self] }
    set { self[PersistentReferencesKey.self] = newValue }
  }
}
