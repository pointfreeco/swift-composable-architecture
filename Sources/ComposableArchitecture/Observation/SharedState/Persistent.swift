#if canImport(Perception)
  /// A type that can persist shared state to an external system.
  ///
  /// See the article <doc:SharingState> for more information.
  public protocol Persistent<Value>: Hashable {
    associatedtype Value
    associatedtype Updates: AsyncSequence = _Empty<Value?> where Updates.Element == Value?

    var updates: Updates { get }
    func load() -> Value?  // TODO: Should this be throwing?
    func save(_ value: Value)
  }

  extension Persistent where Updates == _Empty<Value?> {
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
