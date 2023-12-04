@Reducer
struct ContactsFeature {
  @ObservableState
  struct State: Equatable {
    var contacts: IdentifiedArrayOf<Contact> = []
    @Presents var destination: Destination.State?
  }
  enum Action {
    case addButtonTapped
    case deleteButtonTapped(id: Contact.ID)
    case destination(PresentationAction<Destination.Action>)
    enum Alert: Equatable {
      case confirmDeletion(id: Contact.ID)
    }
  }
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .addButtonTapped:
        state.destination = .addContact(
          AddContactFeature.State(
            contact: Contact(id: UUID(), name: "")
          )
        )
        return .none
        
      case let .addContact(.presented(.delegate(.saveContact(contact)))):
        state.contacts.append(contact)
        return .none
        
      case .addContact:
        return .none
        
      case let .alert(.presented(.confirmDeletion(id: id))):
        state.contacts.remove(id: id)
        return .none
        
      case .alert:
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
    .ifLet(\.$addContact, action: \.addContact) {
      AddContactFeature()
    }
    .ifLet(\.$alert, action: \.alert)
  }
}
