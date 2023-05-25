import ComposableArchitecture

struct ContactDetailFeature: ReducerProtocol {
  struct State: Equatable {
    let contact: Contact
  }
  enum Action {
  }
  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    }
  }
}
