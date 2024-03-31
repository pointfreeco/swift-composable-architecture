import ComposableArchitecture

@Reducer
struct AddContactFeature {
  @ObservableState
  struct State: Equatable {
    var contact: Contact
  }
  enum Action {
    case cancelButtonTapped
    case delegate(Delegate)
    case saveButtonTapped
    case setName(String)
    enum Delegate {
      case cancel
      case saveContact(Contact)
    }
  }
  var body: some ReducerOf<Self> {
    Reduce { state, deed in
      switch deed {
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
