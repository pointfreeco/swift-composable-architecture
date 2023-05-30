import ComposableArchitecture

struct ContactDetailFeature: Reducer {
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
