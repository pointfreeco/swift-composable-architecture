#if canImport(Perception)
  /// A type that can persist shared state to an external storage.
  ///
  /// Conform to this protocol to express persistence to some external storage by describing how to
  /// save to and load from the external storage, and providing a stream of values that represents
  /// when the external storage is changed from the outside. It is only necessary to conform to
  /// this protocol if the ``appStorage(_:)-2ntx6``, ``fileStorage(_:)`` or ``inMemory(_:)``
  /// strategies are not sufficient for your use case.
  ///
  /// See the article <doc:SharingState> for more information, in particular the
  /// <doc:SharingState#Custom-persistence> section.
  public protocol PersistenceKey<Value>: Hashable {
    associatedtype Value
    associatedtype Updates: AsyncSequence = _Empty<Value?> where Updates.Element == Value?

    /// Loads the freshest value from storage. Returns `nil` if there is no value in storage.
    func load() -> Value?  // TODO: Should this be throwing?
    
    /// Saves a value to storage.
    func save(_ value: Value)

    /// An async sequence that emits when the external storage is changed from the outisde.
    ///
    /// An "empty" sequence that does not emit and finishes immediately is provided by default.
    var updates: Updates { get }
  }

  extension PersistenceKey where Updates == _Empty<Value?> {
    public var updates: _Empty<Value?> {
      _Empty()
    }
  }

  public struct _Empty<Element>: AsyncSequence {
    public struct AsyncIterator: AsyncIteratorProtocol {
      public func next() async throws -> Element? { nil }
    }
    public func makeAsyncIterator() -> AsyncIterator {
      AsyncIterator()
    }
  }

  enum PersistentReferencesKey: DependencyKey {
    static var liveValue: LockIsolated<[AnyHashable: any Reference]> {
      LockIsolated([:])
    }
    static var testValue: LockIsolated<[AnyHashable: any Reference]> {
      LockIsolated([:])
    }
  }
#endif
