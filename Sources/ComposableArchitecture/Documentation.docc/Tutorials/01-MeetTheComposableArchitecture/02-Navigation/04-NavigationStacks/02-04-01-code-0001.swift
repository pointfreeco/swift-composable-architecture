import ComposableArchitecture

struct ContactDetailFeature: Reducer {
  struct State: Equatable {
    let contact: Contact
  }
}
