import ComposableArchitecture

struct Root: ReducerProtocol {
  struct State {
    var focus = Focus.State()
  }

  enum Action {
    case focus(Focus.Action)
  }

  var body: some ReducerProtocol<State, Action> {
    Scope(state: \.focus, action: /Action.focus) {
      Focus()
    }
  }
}
