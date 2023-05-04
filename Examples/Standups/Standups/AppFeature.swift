import ComposableArchitecture
import SwiftUI

struct AppFeature: ReducerProtocol {
  struct State: Equatable {
    var path = StackState<Path.State>()
    var standupsList = StandupsList.State()
  }

  enum Action: Equatable {
    case path(StackAction<Path.State, Path.Action>)
    case standupsList(StandupsList.Action)
  }

  @Dependency(\.date.now) var now
  @Dependency(\.uuid) var uuid

  var body: some ReducerProtocolOf<Self> {
    Scope(state: \.standupsList, action: /Action.standupsList) {
      StandupsList()
    }
    Reduce<State, Action> { state, action in
      switch action {
      case let .path(.element(id, action: .detail(.delegate(delegateAction)))):
        guard case let .some(.detail(detailState)) = state.path[id: id]
        else { return .none }

        switch delegateAction {
        case .deleteStandup:
          state.path.pop(from: id)
          state.standupsList.standups.remove(id: detailState.standup.id)
          return .none

        case .startMeeting:
          state.path.append(
            .record(
              RecordMeeting.State(standup: detailState.standup)
            )
          )
          return .none
        }

      case let .path(.element(id, .record(.delegate(delegateAction)))):
        switch delegateAction {
        case let .save(transcript: transcript):
          _ = state.path.pop(from: id)

          XCTModify(&state.path.presented, case: /Path.State.detail) { detailState in
            detailState.standup.meetings.insert(
              Meeting(
                id: Meeting.ID(self.uuid()),
                date: self.now,
                transcript: transcript
              ),
              at: 0
            )
          }

          return .none
        }

      case .path:
        return .none

      case .standupsList:
        return .none
      }
    }
    .forEach(\.path, action: /Action.path) {
      Path()
    }

    Reduce<State, Action> { state, action in
      // NB: Playback any changes made to stand up in detail
      for destination in state.path {
        guard case let .detail(detailState) = destination
        else { continue }
        state.standupsList.standups[id: detailState.standup.id] = detailState.standup
      }
      return .none
    }
  }

  struct Path: ReducerProtocol {
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

    var body: some ReducerProtocol<State, Action> {
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

struct AppView: View {
  let store: StoreOf<AppFeature>

  var body: some View {
    NavigationStackStore(self.store.scope(state: \.path, action: AppFeature.Action.path)) {
      StandupsListView(
        store: self.store.scope(state: \.standupsList, action: AppFeature.Action.standupsList)
      )
    } destination: {
      switch $0 {
      case .detail:
        CaseLet(
          state: /AppFeature.Path.State.detail,
          action: AppFeature.Path.Action.detail,
          then: StandupDetailView.init(store:)
        )
      case .meeting:
        CaseLet(
          state: /AppFeature.Path.State.meeting,
          action: AppFeature.Path.Action.meeting,
          then: MeetingView.init(store:)
        )
      case .record:
        CaseLet(
          state: /AppFeature.Path.State.record,
          action: AppFeature.Path.Action.record,
          then: RecordMeetingView.init(store:)
        )
      }
    }
  }
}
