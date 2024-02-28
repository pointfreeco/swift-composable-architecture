extension ContactsFeature {
  @Reducer
  enum Destination {
    case addContact(AddContactFeature)
  }
}
