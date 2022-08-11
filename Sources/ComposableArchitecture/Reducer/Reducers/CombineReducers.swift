// NB: bug report
public func CombineReducers<State, Action>(
  @ReducerBuilder<State, Action> build: () -> some ReducerProtocol<State, Action>
) -> some ReducerProtocol<State, Action> {
  build()
}
