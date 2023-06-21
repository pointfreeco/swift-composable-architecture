struct ContactsFeature: ReducerProtocol {
  struct State: Equatable {
    @PresentationState var addContact: AddContactFeature.State?
    @PresentationState var alert: AlertState<Action.Alert>?
    var contacts: IdentifiedArrayOf<Contact> = []
  }
  enum Action: Equatable {
    case addButtonTapped
    case addContact(PresentationAction<AddContactFeature.Action>)
    case alert(PresentationAction<Alert>)
    case deleteButtonTapped(id: Contact.ID)
    enum Alert: Equatable {
      case confirmDeletion(id: Contact.ID)
    }
  }
  var body: some ReducerProtocolOf<Self> {
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
        state.alert = AlertState {
          TextState("Are you sure?")
        } actions: {
          ButtonState(role: .destructive, action: .confirmDeletion(id: id)) {
            TextState("Delete")
          }
        }
        return .none
      }
    }
    .ifLet(\.$addContact, action: /Action.addContact) {
      AddContactFeature()
    }
    .ifLet(\.$alert, action: /Action.alert)
  }
}
