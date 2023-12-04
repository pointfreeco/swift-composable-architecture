import ComposableArchitecture

@Reducer
struct ContactDetailFeature {
  @ObservableState
  struct State: Equatable {
    let contact: Contact
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
