extension ContactsFeature {
  @Reducer
  struct Destination {
    @ObservableState
    enum State: Equatable {
      case addContact(AddContactFeature.State)
      case alert(AlertState<ContactsFeature.Action.Alert>)
    }
    enum Action {
      case addContact(AddContactFeature.Action)
      case alert(ContactsFeature.Action.Alert)
    }
  }
}
