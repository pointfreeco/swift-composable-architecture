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
    Scope(\.focus, action: \.focus) {
      Focus()
    }
  }
}
