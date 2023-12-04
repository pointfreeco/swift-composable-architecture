import ComposableArchitecture

@Reducer
struct ContactDetailFeature {
  @ObservableState
  struct State: Equatable {
    @Presents var alert: AlertState<Action.Alert>?
    let contact: Contact
  }
  enum Action {
    case alert(PresentationAction<Alert>)
    case delegate(Delegate)
    case deleteButtonTapped
    enum Alert {
      case confirmDeletion
    }
    enum Delegate {
      case confirmDeletion
    }
  }
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      }
    }
  }
}
