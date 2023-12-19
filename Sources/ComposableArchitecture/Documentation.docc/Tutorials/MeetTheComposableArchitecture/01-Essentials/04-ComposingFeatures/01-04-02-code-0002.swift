import ComposableArchitecture

@Reducer
struct AppFeature {
  struct State {
    var tab1 = CounterFeature.State()
    var tab2 = CounterFeature.State()
  }
  enum Action {
    case tab1(CounterFeature.Action)
    case tab2(CounterFeature.Action)
  }
}
