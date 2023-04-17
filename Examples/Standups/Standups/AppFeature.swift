import ComposableArchitecture

struct AppFeature: Reducer {
  struct State: Equatable {
    var path: StackState<Path.State>
    var standupsList: StandupsList.State
  }

  enum Action: Equatable {
    case path(StackAction<Path.State, Path.Action>)
    case standupsList(StandupsList.Action)
  }

  var body: some ReducerOf<Self> {
    Scope(state: \.standupsList, action: /Action.standupsList) {
      StandupsList()
    }
    .forEach(\.path, action: /Action.path) {
      Path()
    }
  }

  struct Path: Reducer {
    enum State: Hashable {
      case detail(StandupDetail.State)
      case meeting(MeetingReducer.State)
      case record(RecordMeeting.State)
    }

    enum Action: Equatable {
      case detail(StandupDetail.Action)
      case meeting(MeetingReducer.Action)
      case record(RecordMeeting.Action)
    }

    var body: some Reducer<State, Action> {
      Scope(state: /State.detail, action: /Action.detail) {
        StandupDetail()
      }
      Scope(state: /State.meeting, action: /Action.meeting) {
        MeetingReducer()
      }
      Scope(state: /State.record, action: /Action.record) {
        RecordMeeting()
      }
    }
  }
}
