@Reducer
struct ContactsFeature {
  @ObservableState
  struct State: Equatable {
    @Presents var addContact: AddContactFeature.State?
    @Presents var alert: AlertState<Action.Alert>?
    var contacts: IdentifiedArrayOf<Contact> = []
  }
  enum Action {
    case addButtonTapped
    case addContact(PresentationAction<AddContactFeature.Action>)
    case deleteButtonTapped(id: Contact.ID)
    enum Alert: Equatable {
    }
  }
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
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
