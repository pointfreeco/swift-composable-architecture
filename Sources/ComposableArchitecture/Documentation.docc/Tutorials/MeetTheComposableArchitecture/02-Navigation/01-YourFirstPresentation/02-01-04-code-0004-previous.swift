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
  var body: some Reducer<State, Action> {
    Reduce { state, action in
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
}
