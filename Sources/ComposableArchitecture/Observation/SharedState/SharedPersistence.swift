#if canImport(Perception)
  public protocol SharedPersistence<Value> {
    associatedtype Value
    associatedtype Values: AsyncSequence = _Empty<Value> where Values.Element == Value

    var values: Values { get }  // TODO: rename to changes or updates
    func get() -> Value? // TODO: rename to load
    func willSet(value: Value, newValue: Value) // TODO: remove
    func didSet(oldValue: Value, value: Value) // TODO: get rid of oldValue. rename to save
  }

  extension SharedPersistence {
    public func willSet(value _: Value, newValue _: Value) {} // TODO: remove
    public func didSet(oldValue _: Value, value _: Value) {} // TODO: remove
  }

  extension SharedPersistence where Values == _Empty<Value> {
    public var values: _Empty<Value> {
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
#endif
