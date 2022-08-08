// NB: bug report
// TODO: name? GroupReducer, ReducerGroup, CombineReducers, etc...
func GroupReducers<State, Action>(
  @ReducerBuilder<State, Action> build: () -> some ReducerProtocol<State, Action>
) -> some ReducerProtocol<State, Action> {
  build()
}
