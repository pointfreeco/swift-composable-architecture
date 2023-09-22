import ComposableArchitecture
import SwiftUI

struct AppFeature: Reducer {
  @ObservableState
  struct State: Equatable {
    var path = StackState<Path.State>()
    var standupsList = StandupsList.State()
  }

  @CasePathable
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

  var body: some ReducerOf<Self> {
    Scope(state: \.standupsList, action: #casePath(\.standupsList)) {
      StandupsList()
    }
    Reduce { state, action in
      switch action {
      case let .path(.element(id, .detail(.delegate(delegateAction)))):
        guard case let .some(.detail(detailState)) = state.path[id: id]
        else { return .none }

        switch delegateAction {
        case .deleteStandup:
          state.standupsList.standups.remove(id: detailState.standup.id)
          return .none

        case let .standupUpdated(standup):
          state.standupsList.standups[id: standup.id] = standup
          return .none

        case .startMeeting:
          state.path.append(.record(RecordMeeting.State(standup: detailState.standup)))
          return .none
        }

      case let .path(.element(_, .record(.delegate(delegateAction)))):
        switch delegateAction {
        case let .save(transcript: transcript):
          guard let id = state.path.ids.dropLast().last
          else {
            XCTFail(
              """
              Record meeting is the only element in the stack. A detail feature should precede it.
              """
            )
            return .none
          }

          state.path[id: id, case: /Path.State.detail]?.standup.meetings.insert(
            Meeting(
              id: Meeting.ID(self.uuid()),
              date: self.now,
              transcript: transcript
            ),
            at: 0
          )
          guard let standup = state.path[id: id, case: /Path.State.detail]?.standup
          else { return .none }
          state.standupsList.standups[id: standup.id] = standup
          return .none
        }

      case .path:
        return .none

      case .standupsList:
        return .none
      }
    }
    .forEach(\.path, action: #casePath(\.path)) {
      Path()
    }

    Reduce { state, action in
      return .run { [standups = state.standupsList.standups] _ in
        try await withTaskCancellation(id: CancelID.saveDebounce, cancelInFlight: true) {
          try await self.clock.sleep(for: .seconds(1))
          try await self.saveData(JSONEncoder().encode(standups), .standups)
        }
      } catch: { _, _ in
      }
    }
  }

  struct Path: Reducer {
    @CasePathable
    @ObservableState
    enum State: Equatable {
      case detail(StandupDetail.State)
      case meeting(Meeting, standup: Standup)
      case record(RecordMeeting.State)
    }

    @CasePathable
    enum Action: Equatable {
      case detail(StandupDetail.Action)
      case record(RecordMeeting.Action)
    }

    var body: some Reducer<State, Action> {
      Scope(state: #casePath(\.detail), action: #casePath(\.detail)) {
        StandupDetail()
      }
      Scope(state: #casePath(\.record), action: #casePath(\.record)) {
        RecordMeeting()
      }
    }
  }
}

struct AppView: View {
  @State var store: StoreOf<AppFeature>

  var body: some View {
    NavigationStack(store: self.store.scope(#feature(\.path))) {
      StandupsListView(store: self.store.scope(#feature(\.standupsList)))
    } destination: {
      switch $0.state {
      case .detail:
        if let store = $0.scope(state: \.detail, action: { .detail($0) }) {
          StandupDetailView(store: store)
        }
      case let .meeting(meeting, standup: standup):
        MeetingView(meeting: meeting, standup: standup)
      case .record:
        if let store = $0.scope(state: \.record, action: { .record($0) }) {
          RecordMeetingView(store: store)
        }
      }
    }
  }
}

extension URL {
  static let standups = Self.documentsDirectory.appending(component: "standups.json")
}
