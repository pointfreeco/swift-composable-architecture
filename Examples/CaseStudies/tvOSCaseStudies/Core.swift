import ComposableArchitecture

@Reducer
struct Root {
  struct State {
    var focus = Focus.State()
  }

  enum Action {
    case focus(Focus.Action)
  }

  var body: some Reducer<State, Action> {
    Scope(state: \.focus, action: \.focus) {
      Focus()
    }
  }
}
