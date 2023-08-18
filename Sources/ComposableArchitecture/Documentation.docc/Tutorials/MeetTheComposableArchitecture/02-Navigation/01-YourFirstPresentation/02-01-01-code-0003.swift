import ComposableArchitecture

struct AddContactFeature: Reducer {
  struct State: Equatable {
    var contact: Contact
  }
  enum Action: Equatable {
    case cancelButtonTapped
    case saveButtonTapped
    case setName(String)
  }
  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .cancelButtonTapped:
        return .none
        
      case .saveButtonTapped:
        return .none
        
      case let .setName(name):
        state.contact.name = name
        return .none
      }
    }
  }
}
