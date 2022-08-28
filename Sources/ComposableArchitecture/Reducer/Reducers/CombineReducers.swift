/// Combines multiple reducers into a single reducer.
///
/// `CombineReducers` takes a block that can combine a number of reducers using a
/// ``ReducerBuilder``.
///
/// Useful for grouping reducers together and applying reducer modifiers to the result.
///
/// ```swift
/// CombineReducers {
///   ReducerA()
///   ReducerB()
///   ReducerC()
/// }
/// .ifLet(state: \.child, action: /Action.child)
/// ```
public struct CombineReducers<Reducers: ReducerProtocol>: ReducerProtocol {
  @usableFromInline
  let reducers: Reducers

  /// Initializes a reducer that combines all of the reducers in the given build block.
  ///
  /// - Parameter build: A reducer builder.
  @inlinable
  public init(
    @ReducerBuilderOf<Reducers> _ build: () -> Reducers
  ) {
    self.reducers = build()
  }

  @inlinable
  public func reduce(
    into state: inout Reducers.State, action: Reducers.Action
  ) -> Effect<Reducers.Action, Never> {
    self.reducers.reduce(into: &state, action: action)
  }
}

#if swift(>=5.7)
  extension ReducerProtocol {
    // NB: This overload is provided to work around https://github.com/apple/swift/issues/60445
    /// Combines multiple reducers into a single reducer.
    public func CombineReducers<State, Action>(
      @ReducerBuilder<State, Action> _ build: () -> some ReducerProtocol<State, Action>
    ) -> some ReducerProtocol<State, Action> {
      ComposableArchitecture.CombineReducers(build)
    }
  }
#endif
