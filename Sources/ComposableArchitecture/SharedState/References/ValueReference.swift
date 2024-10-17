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
    @Dependency(\.persistentReferences) var references
    let reference = references.withValue { references in
      if let reference = references[persistenceKey.id] as? AnyMutableReference<Value> {
        return reference
      } else {
        let reference = AnyMutableReference(
          ValueReference(
            initialValue: value(),
            persistenceKey: persistenceKey,
            fileID: fileID,
            line: line
          )
        )
        references[persistenceKey.id] = reference
        return reference
      }
    }
    self.init(reference: reference)
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
  ) throws {
    @Dependency(\.persistentReferences) var references
    let reference = try references.withValue { references in
      if let reference = references[persistenceKey.id] as? AnyMutableReference<Value> {
        return reference
      } else {
        let reference = AnyMutableReference(
          ValueReference(
            initialValue: try value(),
            persistenceKey: persistenceKey,
            fileID: fileID,
            line: line
          )
        )
        references[persistenceKey.id] = reference
        return reference
      }
    }
    self.init(reference: reference)
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
    @Dependency(\.persistentReferences) var references
    let reference = references.withValue { references in
      if let reference = references[persistenceKey.id] as? AnyMutableReference<Value> {
        return reference
      } else {
        let reference = AnyMutableReference(
          ValueReference(
            initialValue: value(),
            persistenceKey: persistenceKey,
            fileID: fileID,
            line: line
          )
        )
        references[persistenceKey.id] = reference
        return reference
      }
    }
    self.init(reference: reference)
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
  ) throws {
    @Dependency(\.persistentReferences) var references
    let reference = try references.withValue { references in
      if let reference = references[persistenceKey.id] as? AnyMutableReference<Value> {
        return reference
      } else {
        let reference = AnyMutableReference(
          ValueReference(
            initialValue: try value(),
            persistenceKey: persistenceKey,
            fileID: fileID,
            line: line
          )
        )
        references[persistenceKey.id] = reference
        return reference
      }
    }
    self.init(reference: reference)
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

final class ValueReference<Value, Persistence: PersistenceReaderKey<Value>>:
  HashableObject,
  MutableReference,
  @unchecked Sendable
{
  private let lock = NSRecursiveLock()
  private let id = UUID()
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
  var snapshot: Value? {
    get {
      @Dependency(\.sharedChangeTracker) var changeTracker
      return changeTracker?[self]?.snapshot
    }
    set {
      @Dependency(\.sharedChangeTracker) var changeTracker
      guard let newValue else {
        changeTracker?[self] = nil
        return
      }
      if changeTracker?[self] == nil {
        changeTracker?[self] = AnyChange(self)
      }
      changeTracker?[self]?.snapshot = newValue
    }
  }

  #if canImport(Combine)
    var publisher: any Publisher<Value, Never> {
      self.subject.dropFirst()
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
  var description: String {
    "Shared<\(Value.self)>@\(self.fileID):\(self.line)"
  }
}

#if canImport(Observation)
  extension ValueReference: Observable {}
#endif

extension ValueReference: Perceptible {}

private enum PersistentReferencesKey: DependencyKey {
  static var liveValue: LockIsolated<[AnyHashable: any MutableReference]> {
    LockIsolated([:])
  }
  static var testValue: LockIsolated<[AnyHashable: any MutableReference]> {
    LockIsolated([:])
  }
}

extension DependencyValues {
  var persistentReferences: LockIsolated<[AnyHashable: any MutableReference]> {
    get { self[PersistentReferencesKey.self] }
    set { self[PersistentReferencesKey.self] = newValue }
  }
}
