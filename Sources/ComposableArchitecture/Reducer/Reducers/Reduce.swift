/// A type-erased reducer that invokes the given `reduce` function.
///
/// ``Reduce`` is useful for injecting logic into a reducer tree without the overhead of introducing
/// a new type that conforms to ``ReducerProtocol``.
public struct Reduce<State, Action>: ReducerProtocol {
  @usableFromInline
  let reduce: (inout State, Action) -> EffectTask<Action>

  @usableFromInline
  init(
    internal reduce: @escaping (inout State, Action) -> EffectTask<Action>
  ) {
    self.reduce = reduce
  }

  /// Initializes a reducer with a `reduce` function.
  ///
  /// - Parameter reduce: A function that is called when ``reduce(into:action:)`` is invoked.
  @inlinable
  public init(_ reduce: @escaping (inout State, Action) -> EffectTask<Action>) {
    self.init(internal: reduce)
  }

  /// Initializes a reducer with a `reduce` function and explicit `State` and `Action` types to
  /// assist the compiler in type checking.
  ///
  /// > Specifying `State.self` and `Action.self` as parameter is equivalent to specifying the
  /// > generics in `Reduce<State, Action>`.
  ///
  /// - Parameters:
  ///   - stateType: The type of state. Assists the compiler in type checking the reduce closure.
  ///     Specify when autocompletion fails to suggest properties on state.
  ///   - actionType: The type of action. Assists the compiler in type checking the reduce closure.
  ///     Specify when autocompletion fails to suggest action cases.
  ///   - reduce: A function that is called when ``reduce(into:action:)`` is invoked.
  @inlinable
  public init(
    into stateType: State.Type,
    action actionType: Action.Type,
    _ reduce: @escaping (inout State, Action
  ) -> EffectTask<Action>) {
    self.init(internal: reduce)
  }

  /// Type-erases a reducer.
  ///
  /// - Parameter reducer: A reducer that is called when ``reduce(into:action:)`` is invoked.
  @inlinable
  public init<R: ReducerProtocol>(_ reducer: R)
  where R.State == State, R.Action == Action {
    self.init(internal: reducer.reduce)
  }

  @inlinable
  public func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    self.reduce(&state, action)
  }
}
