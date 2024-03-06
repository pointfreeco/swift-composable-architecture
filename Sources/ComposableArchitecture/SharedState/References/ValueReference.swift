#if canImport(Perception)
  import Foundation
  #if canImport(Combine)
    import Combine
  #endif

  extension Shared {
    @_disfavoredOverload
    public init(_ value: Value, fileID: StaticString = #fileID, line: UInt = #line) {
      self.init(reference: ValueReference(value, fileID: fileID, line: line))
    }

    @_disfavoredOverload
    @available(
      *,
      deprecated,
      message: "Use '@Shared' with a value type or supported reference type"
    )
    public init(_ value: Value, fileID: StaticString = #fileID, line: UInt = #line)
    where Value: AnyObject {
      self.init(reference: ValueReference(value, fileID: fileID, line: line))
    }
    
    public init(
      wrappedValue value: @autoclosure @escaping () -> Value,
      _ persistenceKey: some PersistenceKey<Value>,
      fileID: StaticString = #fileID,
      line: UInt = #line
    ) {
      self.init(
        reference: {
          @Dependency(PersistentReferencesKey.self) var references
          return references.withValue {
            if let reference = $0[persistenceKey] {
              return reference
            } else {
              let reference = ValueReference(
                initialValue: value(),
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

    public init<Wrapped>(
      _ persistenceKey: some PersistenceKey<Value>,
      fileID: StaticString = #fileID,
      line: UInt = #line
    ) where Value == Wrapped? {
      self.init(wrappedValue: nil, persistenceKey, fileID: fileID, line: line)
    }

    @_disfavoredOverload
    @available(
      *,
      deprecated,
      message: "Use '@Shared' with a value type or supported reference type"
    )
    public init(
      wrappedValue value: @autoclosure @escaping () -> Value,
      _ persistenceKey: some PersistenceKey<Value>,
      fileID: StaticString = #fileID,
      line: UInt = #line
    ) where Value: AnyObject {
      self.init(wrappedValue: value(), persistenceKey, fileID: fileID, line: line)
    }
  }

  private final class ValueReference<Value>: Reference {
    private var _currentValue: Value {
      didSet {
        self._subject.send(self._currentValue)
      }
    }
    private var _snapshot: Value?
    fileprivate var persistenceKey: (any PersistenceKey<Value>)?  // TODO: Should this not be an `any`?
    private let fileID: StaticString
    private let line: UInt
    private let lock = NSRecursiveLock()
    private let _$perceptionRegistrar = PerceptionRegistrar(
      isPerceptionCheckingEnabled: _isStorePerceptionCheckingEnabled
    )
    #if canImport(Combine)
      private let _subject: CurrentValueRelay<Value>
    #endif

    init(
      initialValue: @autoclosure @escaping () -> Value,
      persistenceKey: some PersistenceKey<Value>,
      fileID: StaticString,
      line: UInt
    ) {
      self._currentValue = persistenceKey.load() ?? initialValue()
      self._subject = CurrentValueRelay(self._currentValue)
      self.persistenceKey = persistenceKey
      self.fileID = fileID
      self.line = line
      Task { @MainActor [weak self, initialValue] in
        for try await value in persistenceKey.updates {
          self?.currentValue = value ?? initialValue()
        }
      }
    }

    init(
      _ value: Value,
      fileID: StaticString,
      line: UInt
    ) {
      self._currentValue = value
      self._subject = CurrentValueRelay(value)
      self.persistenceKey = nil
      self.fileID = fileID
      self.line = line
    }

    deinit {
      self.assertUnchanged()
    }

    var currentValue: Value {
      _read {
        // TODO: write test for deadlock, unit test and UI test
        self._$perceptionRegistrar.access(self, keyPath: \.currentValue)
        self.lock.lock()
        defer { self.lock.unlock() }
        yield self._currentValue
      }
      _modify {
        self._$perceptionRegistrar.willSet(self, keyPath: \.currentValue)
        defer { self._$perceptionRegistrar.didSet(self, keyPath: \.currentValue) }
        self.lock.lock()
        defer { self.lock.unlock() }
        yield &self._currentValue
        self.persistenceKey?.save(self._currentValue)
      }
      set {
        self._$perceptionRegistrar.withMutation(of: self, keyPath: \.currentValue) {
          self.lock.withLock {
            self._currentValue = newValue
            self.persistenceKey?.save(self._currentValue)
          }
        }
      }
    }

    var snapshot: Value? {
      _read {
        self.lock.lock()
        defer { self.lock.unlock() }
        yield self._snapshot
      }
      _modify {
        self.lock.lock()
        defer { self.lock.unlock() }
        yield &self._snapshot
      }
      set {
        self.lock.withLock { self._snapshot = newValue }
      }
    }

    var publisher: AnyPublisher<Value, Never> {
      self._subject.dropFirst().eraseToAnyPublisher()
    }

    var description: String {
      "Shared<\(Value.self)>@\(self.fileID):\(self.line)"
    }
  }

  extension ValueReference: Equatable where Value: Equatable {
    static func == (lhs: ValueReference, rhs: ValueReference) -> Bool {
      if lhs === rhs {
        return lhs.snapshot ?? lhs.currentValue == rhs.currentValue
      } else {
        return lhs.currentValue == rhs.currentValue
      }
    }
  }

  #if !os(visionOS)
    extension ValueReference: Perceptible {}
  #endif

  #if canImport(Observation)
    extension ValueReference: Observable {}
  #endif
#endif
