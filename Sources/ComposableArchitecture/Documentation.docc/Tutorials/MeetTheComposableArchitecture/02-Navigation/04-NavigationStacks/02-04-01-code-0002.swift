import ComposableArchitecture

@Reducer
struct ContactDetailFeature {
  struct State: Equatable {
    let contact: Contact
  }
  enum Action {
  }
}
