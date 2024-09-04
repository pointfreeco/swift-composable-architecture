/// A type-erased reducer that invokes the given `reduce` function.
///
/// ``Reduce`` is useful for injecting logic into a reducer tree without the overhead of introducing
/// a new type that conforms to ``Reducer``.
public struct Reduce<State, Action>: Reducer {
  @usableFromInline
  let reduce: (inout State, Action) -> Effect<Action>

  @usableFromInline
  init(
    internal reduce: @escaping (inout State, Action) -> Effect<Action>
  ) {
    self.reduce = reduce
  }

  /// Initializes a reducer with a `reduce` function.
  ///
  /// - Parameter reduce: A function that is called when ``reduce(into:action:)`` is invoked.
  @inlinable
  public init(_ reduce: @escaping (_ state: inout State, _ action: Action) -> Effect<Action>) {
    self.init(internal: reduce)
  }

  /// Type-erases a reducer.
  ///
  /// - Parameter reducer: A reducer that is called when ``reduce(into:action:)`` is invoked.
  @inlinable
  public init(_ reducer: some Reducer<State, Action>) {
    self.init(internal: reducer.reduce)
  }

  @inlinable
  public func reduce(into state: inout State, action: Action) -> Effect<Action> {
    self.reduce(&state, action)
  }
}
