extension ContactsFeature {
  struct Destination: Reducer {
    enum State: Equatable {
      case addContact(AddContactFeature.State)
      case alert(AlertState<ContactsFeature.Action.Alert>)
    }
  }
}
