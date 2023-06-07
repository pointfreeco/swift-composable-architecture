import ComposableArchitecture

struct AddContactFeature: ReducerProtocol {
  struct State: Equatable {
    var contact: Contact
  }
  enum Action: Equatable {
    case cancelButtonTapped
    case delegate(Delegate)
    case saveButtonTapped
    case setName(String)
    enum Delegate {
      case cancel
      case saveContact(Contact)
    }
  }
  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    case .cancelButtonTapped:
      return .send(.delegate(.cancel))

    case .delegate:
      return .none

    case .saveButtonTapped:
      return .send(.delegate(.saveContact(state.contact)))

    case let .setName(name):
      state.contact.name = name
      return .none
    }
  }
}
