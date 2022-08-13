// NB: The following is implemented as a function rather than a type conforming to the reducer
// protocol due to a bug in Swift:
//
// https://github.com/apple/swift/issues/60445

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
///
/// - Parameter build: A reducer builder.
/// - Returns: A reducer combining all of the reducers in the build block.
public func CombineReducers<State, Action>(
  @ReducerBuilder<State, Action> _ build: () -> some ReducerProtocol<State, Action>
) -> some ReducerProtocol<State, Action> {
  build()
}
