import ComposableArchitecture

struct AddContactFeature: ReducerProtocol {
  struct State: Equatable {
    var contact: Contact
  }
  enum Action {
    case cancelButtonTapped
    case delegate(Delegate)
    case saveButtonTapped
    case setName(String)
    enum Delegate {
      //case cancel
      case saveContact(Contact)
    }
  }
  @Dependency(\.dismiss) var dismiss
  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    case .cancelButtonTapped:
      return .fireAndForget { await self.dismiss() }
    case .delegate:
      return .none
    case .saveButtonTapped:
      return .run { [contact = state.contact] send in
        await send(.delegate(.saveContact(state.contact)))
        await self.dismiss()
      }
    case let .setName(name):
      state.contact.name = name
      return .none
    }
  }
}
