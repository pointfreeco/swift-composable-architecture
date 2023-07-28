import ComposableArchitecture

struct ContactDetailFeature: Reducer {
  struct State: Equatable {
    @PresentationState var alert: AlertState<Action.Alert>?
    let contact: Contact
  }
  enum Action: Equatable {
  }
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      }
    }
  }
}
