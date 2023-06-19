import ComposableArchitecture

struct AddContactFeature: Reducer {
  struct State: Equatable {
    var contact: Contact
  }
  enum Action: Equatable {
    case cancelButtonTapped
    case delegate(Delegate)
    case saveButtonTapped
    case setName(String)
    enum Delegate: Equatable {
      case cancel
      case saveContact(Contact)
    }
  }
  func reduce(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .cancelButtonTapped:
      return .none

    case .delegate:
      return .none

    case .saveButtonTapped:
      return .none

    case let .setName(name):
      state.contact.name = name
      return .none
    }
  }
}
