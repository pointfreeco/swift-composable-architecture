/// A reducer that does nothing.
///
/// While not very useful on its own, `EmptyReducer` can be used as a placeholder in APIs that hold
/// reducers.
public struct EmptyReducer<State, Action>: ReducerProtocol {
  /// Initializes a reducer that does nothing.
  @inlinable
  public init() {
    self.init(internal: ())
  }

  @usableFromInline
  init(internal: Void) {}

  @inlinable
  public func reduce(into _: inout State, action _: Action) -> EffectTask<Action> {
    .none
  }
}
