import ComposableArchitecture
import SwiftUI

struct AppFeature: Reducer {
  struct State: Equatable {
    var path = StackState<Path.State>()
    var syncUpsList = SyncUpsList.State()
  }

  enum Action: Equatable {
    case path(StackAction<Path.State, Path.Action>)
    case syncUpsList(SyncUpsList.Action)
  }

  @Dependency(\.continuousClock) var clock
  @Dependency(\.date.now) var now
  @Dependency(\.dataManager.save) var saveData
  @Dependency(\.uuid) var uuid

  private enum CancelID {
    case saveDebounce
  }

  var body: some ReducerOf<Self> {
    Scope(state: \.syncUpsList, action: /Action.syncUpsList) {
      SyncUpsList()
    }
    Reduce { state, action in
      switch action {
      case let .path(.element(id, .detail(.delegate(delegateAction)))):
        guard case let .some(.detail(detailState)) = state.path[id: id]
        else { return .none }

        switch delegateAction {
        case .deleteSyncUp:
          state.syncUpsList.syncUps.remove(id: detailState.syncUp.id)
          return .none

        case let .syncUpUpdated(syncUp):
          state.syncUpsList.syncUps[id: syncUp.id] = syncUp
          return .none

        case .startMeeting:
          state.path.append(.record(RecordMeeting.State(syncUp: detailState.syncUp)))
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

          state.path[id: id, case: /Path.State.detail]?.syncUp.meetings.insert(
            Meeting(
              id: Meeting.ID(self.uuid()),
              date: self.now,
              transcript: transcript
            ),
            at: 0
          )
          guard let syncUp = state.path[id: id, case: /Path.State.detail]?.syncUp
          else { return .none }
          state.syncUpsList.syncUps[id: syncUp.id] = syncUp
          return .none
        }

      case .path:
        return .none

      case .syncUpsList:
        return .none
      }
    }
    .forEach(\.path, action: /Action.path) {
      Path()
    }

    Reduce { state, action in
      return .run { [syncUps = state.syncUpsList.syncUps] _ in
        try await withTaskCancellation(id: CancelID.saveDebounce, cancelInFlight: true) {
          try await self.clock.sleep(for: .seconds(1))
          try await self.saveData(JSONEncoder().encode(syncUps), .syncUps)
        }
      } catch: { _, _ in
      }
    }
  }

  struct Path: Reducer {
    enum State: Equatable {
      case detail(SyncUpDetail.State)
      case meeting(Meeting, syncUp: SyncUp)
      case record(RecordMeeting.State)
    }

    enum Action: Equatable {
      case detail(SyncUpDetail.Action)
      case record(RecordMeeting.Action)
    }

    var body: some Reducer<State, Action> {
      Scope(state: /State.detail, action: /Action.detail) {
        SyncUpDetail()
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
      SyncUpsListView(
        store: self.store.scope(state: \.syncUpsList, action: { .syncUpsList($0) })
      )
    } destination: {
      switch $0 {
      case .detail:
        CaseLet(
          /AppFeature.Path.State.detail,
          action: AppFeature.Path.Action.detail,
          then: SyncUpDetailView.init(store:)
        )
      case let .meeting(meeting, syncUp: syncUp):
        MeetingView(meeting: meeting, syncUp: syncUp)
      case .record:
        CaseLet(
          /AppFeature.Path.State.record,
          action: AppFeature.Path.Action.record,
          then: RecordMeetingView.init(store:)
        )
      }
    }
  }
}

extension URL {
  static let syncUps = Self.documentsDirectory.appending(component: "sync-ups.json")
}
