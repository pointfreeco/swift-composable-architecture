/// Combines multiple reducers into a single reducer.
///
/// `CombineReducers` takes a block that can combine a number of reducers using a
/// ``ReducerBuilder``.
///
/// Useful for grouping reducers together and applying reducer modifiers to the result.
///
/// ```swift
/// var body: some Reducer<State, Action> {
///   CombineReducers {
///     ReducerA()
///     ReducerB()
///     ReducerC()
///   }
///   ._printChanges()
/// }
/// ```
public struct CombineReducers<State, Action, Reducers: Reducer>: Reducer
where State == Reducers.State, Action == Reducers.Action {
  @usableFromInline
  let reducers: Reducers

  /// Initializes a reducer that combines all of the reducers in the given build block.
  ///
  /// - Parameter build: A reducer builder.
  @inlinable
  public init(
    @ReducerBuilder<State, Action> _ build: () -> Reducers
  ) {
    self.init(internal: build())
  }

  @usableFromInline
  init(internal reducers: Reducers) {
    self.reducers = reducers
  }

  @inlinable
  public func reduce(
    into state: inout Reducers.State, action: Reducers.Action
  ) -> Effect<Reducers.Action> {
    self.reducers.reduce(into: &state, action: action)
  }
}
