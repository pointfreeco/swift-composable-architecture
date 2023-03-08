/// A reducer that builds a reducer from the current state and action.
public struct ReducerReader<State, Action, Reader: ReducerProtocol>: ReducerProtocol
where Reader.State == State, Reader.Action == Action {
  @usableFromInline
  let reader: (State, Action) -> Reader

  /// Initializes a reducer that builds a reducer from the current state and action.
  ///
  /// - Parameter reader: A reducer builder that has access to the current state and action.
  @inlinable
  public init(@ReducerBuilder<State, Action> _ reader: @escaping (State, Action) -> Reader) {
    self.init(internal: reader)
  }

  @usableFromInline
  init(internal reader: @escaping (State, Action) -> Reader) {
    self.reader = reader
  }

  @inlinable
  public func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    self.reader(state, action).reduce(into: &state, action: action)
  }
}
