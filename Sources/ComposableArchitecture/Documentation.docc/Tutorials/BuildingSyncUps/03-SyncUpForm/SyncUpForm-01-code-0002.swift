import ComposableArchitecture

@Reducer
struct SyncUpForm {
  @ObservableState
  struct State {
    var syncUp: SyncUp
  }

  enum Action {
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      }
    }
  }
}
