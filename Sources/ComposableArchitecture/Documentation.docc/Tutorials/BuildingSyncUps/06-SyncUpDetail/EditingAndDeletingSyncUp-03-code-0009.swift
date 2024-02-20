import ComposableArchitecture

@Reducer
struct SyncUpDetail {
  @ObservableState
  struct State {
    @Presents var destination: Destination.State?
    @Shared var syncUp: SyncUp
  }

  enum Action {
    case cancelEditButtonTapped
    case delegate(Delegate)
    case deleteButtonTapped
    case destination(PresentationAction<Destination.Action>)
    case doneEditingButtonTapped
    case editButtonTapped
    case startMeetingButtonTapped
    enum Alert {
      case confirmButtonTapped
    }
  }

  @Dependency(\.dismiss) var dismiss

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      // case .alert(.presented(.confirmButtonTapped)):
      case .destination(.presented(.alert(.confirmButtonTapped))):
        return .run { send in
          await send(.delegate(.deleteSyncUp(id: state.syncUp.id)))
          await dismiss()
        }

      case .destination(.dismiss):
        return .none

      case .cancelEditButtonTapped:
        state.destination = nil
        return .none

      case .delegate:
        return .none

      case .deleteButtonTapped:
        // state.alert = .deleteSyncUp
        state.destination = .alert(.deleteSyncUp)
        return .none

      case .doneEditingButtonTapped:
        guard let editedSyncUp = state.editSyncUp?.syncUp
        else { return .none }
        state.syncUp = editedSyncUp
        return .none

      case .editButtonTapped:
        state.editSyncUp = SyncUpForm.State(syncUp: state.syncUp)
        return .none

      case .startMeetingButtonTapped:
        return .none
      }
    }
    .ifLet(\.$destination, action: \.destination)
  }
}

extension AlertState where Action == SyncUpDetail.Action.Alert {
  static let deleteSyncUp = Self {
    TextState("Delete?")
  } actions: {
    ButtonState(role: .destructive, action: .confirmButtonTapped) {
      TextState("Yes")
    }
    ButtonState(role: .cancel) {
      TextState("Nevermind")
    }
  } message: {
    TextState("Are you sure you want to delete this meeting?")
  }
}

struct SyncUpDetail.Destination {
  // ...
}

struct SyncUpDetailView: View {
  // ...
}
