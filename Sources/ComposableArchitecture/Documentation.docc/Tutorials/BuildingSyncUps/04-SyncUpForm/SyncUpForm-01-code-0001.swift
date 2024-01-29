import ComposableArchitecture

@Reducer
struct SyncUpForm {
  @ObservableState
  struct State {
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
