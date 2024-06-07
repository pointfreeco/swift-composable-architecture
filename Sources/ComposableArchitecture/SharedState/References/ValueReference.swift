import Dependencies
import Foundation

#if canImport(Combine)
  import Combine
#endif
#if canImport(Perception)
  import Perception
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
    wrappedValue value: @autoclosure @escaping () -> Value,
    _ persistenceKey: some PersistenceKey<Value>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.init(
      reference: {
        @Dependency(\.persistentReferences) var references
        return references.withValue {
          if let reference = $0[persistenceKey.id] {
            precondition(
              reference.valueType == Value.self,
              """
              "\(typeName(Value.self, genericsAbbreviated: false))" does not match existing \
              persistent reference "\(typeName(reference.valueType, genericsAbbreviated: false))" \
              (key: "\(persistenceKey.id)")
              """
            )
            return reference
          } else {
            let reference = ValueReference(
              initialValue: value(),
              persistenceKey: persistenceKey,
              fileID: fileID,
              line: line
            )
            $0[persistenceKey.id] = reference
            return reference
          }
        }
      }(),
      keyPath: \Value.self
    )
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
    throwingValue value: @autoclosure @escaping () throws -> Value,
    _ persistenceKey: some PersistenceKey<Value>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) throws {
    try self.init(
      reference: {
        @Dependency(\.persistentReferences) var references
        return try references.withValue {
          if let reference = $0[persistenceKey.id] {
            precondition(
              reference.valueType == Value.self,
              """
              "\(typeName(Value.self, genericsAbbreviated: false))" does not match existing \
              persistent reference "\(typeName(reference.valueType, genericsAbbreviated: false))" \
              (key: "\(persistenceKey.id)")
              """
            )
            return reference
          } else {
            let reference = try ValueReference(
              initialValue: value(),
              persistenceKey: persistenceKey,
              fileID: fileID,
              line: line
            )
            $0[persistenceKey.id] = reference
            return reference
          }
        }
      }(),
      keyPath: \Value.self
    )
  }

  /// Creates a shared reference to a value using a persistence key with a default value.
  ///
  /// - Parameters:
  ///   - persistenceKey: A persistence key associated with the shared reference. It is responsible
  ///     for loading and saving the shared reference's value from some external source.
  public init<Key: PersistenceKey>(
    _ persistenceKey: PersistenceKeyDefault<Key>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) where Key.Value == Value {
    self.init(
      wrappedValue: persistenceKey.load(initialValue: nil) ?? persistenceKey.defaultValue(),
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
  public init<Key: PersistenceKey>(
    wrappedValue value: @autoclosure @escaping () -> Value,
    _ persistenceKey: PersistenceKeyDefault<Key>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) where Key.Value == Value {
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
    wrappedValue value: @autoclosure @escaping () -> Value,
    _ persistenceKey: some PersistenceReaderKey<Value>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.init(
      reference: {
        @Dependency(\.persistentReferences) var references
        return references.withValue {
          if let reference = $0[persistenceKey.id] {
            precondition(
              reference.valueType == Value.self,
              """
              Type mismatch at persistence key "\(persistenceKey.id)": \
              \(reference.valueType) != \(Value.self)
              """
            )
            return reference
          } else {
            let reference = ValueReference(
              initialValue: value(),
              persistenceKey: persistenceKey,
              fileID: fileID,
              line: line
            )
            $0[persistenceKey.id] = reference
            return reference
          }
        }
      }(),
      keyPath: \Value.self
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
    throwingValue value: @autoclosure @escaping () throws -> Value,
    _ persistenceKey: some PersistenceReaderKey<Value>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) throws {
    try self.init(
      reference: {
        @Dependency(\.persistentReferences) var references
        return try references.withValue {
          if let reference = $0[persistenceKey.id] {
            precondition(
              reference.valueType == Value.self,
              """
              Type mismatch at persistence key "\(persistenceKey.id)": \
              \(reference.valueType) != \(Value.self)
              """
            )
            return reference
          } else {
            let reference = ValueReference(
              initialValue: try value(),
              persistenceKey: persistenceKey,
              fileID: fileID,
              line: line
            )
            $0[persistenceKey.id] = reference
            return reference
          }
        }
      }(),
      keyPath: \Value.self
    )
  }

  /// Creates a shared reference to a read-only value using a persistence key with a default value.
  ///
  /// - Parameters:
  ///   - persistenceKey: A persistence key associated with the shared reference. It is responsible
  ///     for loading the shared reference's value from some external source.
  public init<Key: PersistenceReaderKey>(
    _ persistenceKey: PersistenceKeyDefault<Key>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) where Key.Value == Value {
    self.init(
      wrappedValue: persistenceKey.load(initialValue: nil) ?? persistenceKey.defaultValue(),
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
  public init<Key: PersistenceReaderKey>(
    wrappedValue value: @autoclosure @escaping () -> Value,
    _ persistenceKey: PersistenceKeyDefault<Key>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) where Key.Value == Value {
    self.init(
      wrappedValue: value(),
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
