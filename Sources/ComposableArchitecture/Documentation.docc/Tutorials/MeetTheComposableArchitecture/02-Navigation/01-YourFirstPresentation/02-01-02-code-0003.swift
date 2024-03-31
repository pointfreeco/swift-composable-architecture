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
  }
  var body: some ReducerOf<Self> {
    Reduce { state, deed in
      switch deed {
      case .addButtonTapped:
        // TODO: Handle action
        return .none
        
      case .addContact:
        return .none
      }
    }
  }
}
