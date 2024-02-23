import ComposableArchitecture

@Reducer
struct SyncUpDetail {
  @ObservableState
  struct State {
    @Presents var editSyncUp: SyncUpForm.State?
    @Shared var syncUp: SyncUp
  }

  enum Action {
    case cancelEditButtonTapped
    case deleteButtonTapped
    case doneEditingButtonTapped
    case editButtonTapped
    case editSyncUp(PresentationAction<SyncUpForm.Action>)
    case startMeetingButtonTapped
    enum Alert {
      case confirmButtonTapped
    }
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .cancelEditButtonTapped:
        state.editSyncUp = nil
        return .none

      case .deleteButtonTapped:
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
    .ifLet(\.$editSyncUp, action: \.editSyncUp) {
      SyncUpForm()
    }
  }
}

struct SyncUpDetailView: View {
  // ...
}
