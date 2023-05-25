import ComposableArchitecture

struct ContactDetailFeature: ReducerProtocol {
  struct State: Equatable {
    let contact: Contact
  }
  enum Action {
  }
  var body: some ReducerProtocolOf<Self> {
    Reduce { state, action in
      switch action {

      }
    }
  }
}
