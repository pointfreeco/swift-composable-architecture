/// A reducer that invokes the given `reduce` function.
///
/// ``Reduce`` is the primary unit of a reducer composition. It is given direct mutable access to
/// application ``Reducer/State`` whenever an ``Reducer/Action`` is fed into the system, and returns
/// an ``Effect`` that can communicate with the outside world and feed additional
/// ``Reducer/Action``s back into the system.
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
  /// - Parameter reduce: A function that is called when the reducer is invoked.
  @inlinable
  public init(_ reduce: @escaping (_ state: inout State, _ action: Action) -> Effect<Action>) {
    self.init(internal: reduce)
  }

  /// Type-erases a reducer.
  ///
  /// - Parameter reducer: A reducer that is called when the reducer is invoked.
  @inlinable
  public init<R: Reducer>(_ reducer: R)
  where R.State == State, R.Action == Action {
    self.init(internal: reducer.reduce)
  }

  @inlinable
  public func reduce(into state: inout State, action: Action) -> Effect<Action> {
    self.reduce(&state, action)
  }
}
