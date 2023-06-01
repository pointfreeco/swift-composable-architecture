extension ContactsFeature {
  struct Destination: ReducerProtocol {
    enum State: Equatable {
      case addContact(AddContactFeature.State)
      case alert(AlertState<ContactsFeature.Action.Alert>)
    }
  }
}
