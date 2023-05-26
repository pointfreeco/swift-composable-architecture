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

  @Dependency(\.continuousClock) var clock
  @Dependency(\.date.now) var now
  @Dependency(\.dataManager.save) var saveData
  @Dependency(\.uuid) var uuid

  private enum CancelID {
    case saveDebounce
  }

  var body: some ReducerProtocolOf<Self> {
    Scope(state: \.standupsList, action: /Action.standupsList) {
      StandupsList()
    }
    Reduce<State, Action> { state, action in
      switch action {
      case let .path(.popFrom(id)):
        guard case let .some(.detail(detailState)) = state.path[id: id]
        else { return .none }
        state.standupsList.standups[id: detailState.standup.id]? = detailState.standup
        return .none

      case let .path(.element(id, .detail(.delegate(delegateAction)))):
        guard case let .some(.detail(detailState)) = state.path[id: id]
        else { return .none }

        switch delegateAction {
        case .deleteStandup:
          state.standupsList.standups.remove(id: detailState.standup.id)
          return .none

        case .startMeeting:
          state.path.append(.record(RecordMeeting.State(standup: detailState.standup)))
          return .none
        }

      case let .path(.element(id, .record(.delegate(delegateAction)))):
        switch delegateAction {
        case let .save(transcript: transcript):
          state.path.pop(from: id)

          guard let id = state.path.ids.last
          else { return .none }

          state.path[id: id, case: /Path.State.detail]?.standup.meetings.insert(
            Meeting(
              id: Meeting.ID(self.uuid()),
              date: self.now,
              transcript: transcript
            ),
            at: 0
          )
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
      return .run { [standups = state.standupsList.standups] _ in
        try await withTaskCancellation(id: CancelID.saveDebounce, cancelInFlight: true) {
          try await self.clock.sleep(for: .seconds(1))
          try await self.saveData(JSONEncoder().encode(standups), .standups)
        }
      } catch: { _, _ in
      }
    }
  }

  struct Path: ReducerProtocol {
    enum State: Equatable {
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
    NavigationStackStore(self.store.scope(state: \.path, action: { .path($0) })) {
      StandupsListView(
        store: self.store.scope(state: \.standupsList, action: { .standupsList($0) })
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

extension URL {
  static let standups = Self.documentsDirectory.appending(component: "standups.json")
}
