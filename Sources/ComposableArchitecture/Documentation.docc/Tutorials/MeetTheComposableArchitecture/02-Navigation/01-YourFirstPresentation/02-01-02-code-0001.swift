@Reducer
struct ContactsFeature {
  struct State: Equatable {
    @PresentationState var addContact: AddContactFeature.State?
    var contacts: IdentifiedArrayOf<Contact> = []
  }
  enum Action {
    case addButtonTapped
  }
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .addButtonTapped:
        // TODO: Handle action
        return .none
      }
    }
  }
}
