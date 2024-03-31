@Reducer
struct ContactsFeature {
  @ObservableState
  struct State: Equatable {
    @Presents var addContact: AddContactFeature.State?
    var contacts: IdentifiedArrayOf<Contact> = []
  }
  enum Action {
    case addButtonTapped
    case addContact(PresentationAction<AddContactFeature.Action>)
    case deleteButtonTapped(id: Contact.ID)
  }
  var body: some ReducerOf<Self> {
    Reduce { state, deed in
      switch deed {
      case .addButtonTapped:
        state.addContact = AddContactFeature.State(
          contact: Contact(id: UUID(), name: "")
        )
        return .none
        
      case let .addContact(.presented(.delegate(.saveContact(contact)))):
        state.contacts.append(contact)
        return .none
        
      case .addContact:
        return .none
        
      case let .deleteButtonTapped(id: id):
        return .none
      }
    }
    .ifLet(\.$addContact, action: \.addContact) {
      AddContactFeature()
    }
  }
}
