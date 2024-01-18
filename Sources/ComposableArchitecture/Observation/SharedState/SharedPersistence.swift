#if canImport(Perception)
  public protocol SharedPersistence<Value> {
    associatedtype Value
    associatedtype Values: AsyncSequence = _Empty<Value> where Values.Element == Value

    var values: Values { get }
    func get() -> Value?
    func willSet(value: Value, newValue: Value)
    func didSet(oldValue: Value, value: Value)
  }

  extension SharedPersistence {
    public func willSet(value _: Value, newValue _: Value) {}
    public func didSet(oldValue _: Value, value _: Value) {}
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
