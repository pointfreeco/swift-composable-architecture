import ComposableArchitecture

@Reducer
struct SyncUpDetail {
  @ObservableState
  struct State {
    @Presents var editSyncUp: SyncUpForm.State?
    var syncUp: SyncUp
  }

  enum Action {
    case deleteButtonTapped
    case editButtonTapped
    case startMeetingButtonTapped
    case meetingTapped(id: Meeting.ID)
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .deleteButtonTapped:
        return .none

      case .editButtonTapped:
        return .none

      case .startMeetingButtonTapped:
        return .none

      case let .meetingTapped(id: id):
        return .none
      }
    }
  }
}

struct SyncUpDetailView: View {
  // ...
}
