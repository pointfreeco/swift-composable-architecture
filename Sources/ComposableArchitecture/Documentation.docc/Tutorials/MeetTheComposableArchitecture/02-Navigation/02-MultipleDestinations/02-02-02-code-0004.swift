extension ContactsFeature {
  @Reducer(state: .equatable)
  enum Destination {
    case addContact(AddContactFeature)
    case alert(AlertState<ContactsFeature.Action.Alert>)
  }
}
