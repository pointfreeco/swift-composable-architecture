import ComposableArchitecture

@Reducer
struct SyncUpDetail {
  @ObservableState
  struct State {
    @Presents var alert: AlertState<Action.Alert>?
    @Presents var editSyncUp: SyncUpForm.State?
    var syncUp: SyncUp
  }

  enum Action {
    case alert(PresentationAction<Alert>)
    case cancelEditButtonTapped
    case delegate(Delegate)
    case deleteButtonTapped
    case doneEditingButtonTapped
    case editButtonTapped
    case editSyncUp(PresentationAction<SycnUpForm.Action>)
    case startMeetingButtonTapped
    case meetingTapped(id: Meeting.ID)
    enum Alert {
      case confirmButtonTapped
    }
    enum Delegate {
      case deleteSyncUp(id: SyncUp.ID)
    }
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .alert(.presented(.confirmButtonTapped)):
        
      case .alert(.dismiss):
        return .none

      case .cancelEditButtonTapped:
        state.editSyncUp = nil
        return .none

      case .delegate:
        return .none

      case .deleteButtonTapped:
        state.alert = .deleteSyncUp
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

      case let .meetingTapped(id: id):
        return .none
      }
    }
    .ifLet(\.$editSyncUp, action: \.editSyncUp) {
      SyncUpForm()
    }
    .ifLet(\.$alert, action: \.alert) 
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

struct SyncUpDetailView: View {
  // ...
}