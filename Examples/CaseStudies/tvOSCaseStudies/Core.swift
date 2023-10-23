import ComposableArchitecture

struct Root: Reducer {
  struct State {
    var focus = Focus.State()
  }

  @CasePathable
  enum Action {
    case focus(Focus.Action)
  }

  var body: some Reducer<State, Action> {
    Scope(state: \.focus, action: \.focus) {
      Focus()
    }
  }
}
