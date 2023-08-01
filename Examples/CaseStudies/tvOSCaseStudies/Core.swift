import ComposableArchitecture

struct Root: Reducer {
  struct State {
    var focus = Focus.State()
  }

  enum Action {
    case focus(Focus.Action)
  }

  var body: some Reducer<State, Action> {
    Scope(state: \.focus, action: /Action.focus) {
      Focus()
    }
  }
}
