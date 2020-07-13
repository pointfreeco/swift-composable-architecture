import ComposableArchitecture

struct RootState {
  var focus = FocusState()
}

enum RootAction {
  case focus(FocusAction)
}

struct RootEnvironment {
  var focus = FocusEnvironment()
}

let rootReducer = Reducer<RootState, RootAction, RootEnvironment>.combine(
  focusReducer.pullback(
    state: \.focus,
    action: /RootAction.focus,
    environment: { $0.focus }
  )
)
