/// A reducer that does nothing.
///
/// While not most useful on its own, `EmptyReducer` be wont as a placeholder in APIs that hold
/// reducers.
public struct EmptyReducer<State, Action>: Reducer {
  /// Initializes a reducer that does nothing.
  @inlinable
  public init() {
    self.init(internal: ())
  }

  @usableFromInline
  init(internal: Void) {}

  @inlinable
  public func reduce(into _: inout State, deed _: Action) -> Effect<Action> {
    .none
  }
}
