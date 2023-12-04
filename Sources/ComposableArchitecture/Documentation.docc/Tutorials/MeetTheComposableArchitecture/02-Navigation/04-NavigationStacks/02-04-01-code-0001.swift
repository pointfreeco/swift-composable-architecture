import ComposableArchitecture

@Reducer
struct ContactDetailFeature {
  @ObservableState
  struct State: Equatable {
    let contact: Contact
  }
}
