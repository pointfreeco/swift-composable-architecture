import ComposableArchitecture

extension AlertState where Action == ContactsFeature.Action.Alert {
  static func deleteConfirmation(id: UUID) -> Self {
    Self {
      TextState("Are you sure?")
    } actions: {
      ButtonState(role: .destructive, action: .confirmDeletion(id: id)) {
        TextState("Delete")
      }
    }
  }
}
