extension ContactsFeature {
  struct Destination: Reducer {
    @CasePathable
    enum State: Equatable {
      case addContact(AddContactFeature.State)
      case alert(AlertState<ContactsFeature.Action.Alert>)
    }
    @CasePathable
    enum Action: Equatable {
      case addContact(AddContactFeature.Action)
      case alert(ContactsFeature.Action.Alert)
    }
    var body: some ReducerOf<Self> {
      Scope(state: \.addContact, action: \.addContact) {
        AddContactFeature()
      }
    }
  }
}
