import ComposableArchitecture
import SwiftUI

@Reducer
struct AppFeature {
  @ObservableState
  struct State: Equatable {
    var path: StackState<Path.State>
    var syncUpsList: SyncUpsList.State

    @MainActor
    init(
      path: StackState<Path.State> = StackState<Path.State>(),
      syncUpsList: SyncUpsList.State? = nil
    ) {
      self.path = path
      self.syncUpsList = syncUpsList ?? SyncUpsList.State()
    }
  }

  enum Action {
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
    Scope(state: \.syncUpsList, action: \.syncUpsList) {
      SyncUpsList()
    }
    Reduce<State, Action> { state, action in
      switch action {
      case let .syncUpsList(.syncUpTapped(id: id)):
        state.path.append(
          .detail(SyncUpDetail.State(syncUp: state.syncUpsList.syncUps[id: id]!))
        )
        return .none

      case let .path(.element(id, .detail(.delegate(delegateAction)))):
        guard case let .some(.detail(detailState)) = state.path[id: id]
        else { return .none }

        switch delegateAction {
        case .deleteSyncUp:
          state.syncUpsList.syncUps.remove(id: detailState.syncUp.id)
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

          state.path[id: id, case: \.detail]?.syncUp.meetings.insert(
            Meeting(
              id: Meeting.ID(self.uuid()),
              date: self.now,
              transcript: transcript
            ),
            at: 0
          )
          guard let syncUp = state.path[id: id, case: \.detail]?.syncUp
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
    .forEach(\.path, action: \.path) {
      Path()
    }

//    Reduce { state, action in
//      guard let data = try? JSONEncoder().encode(state.syncUpsList.syncUps)
//      else { return .none }
//      return .run { _ in
//        try await withTaskCancellation(id: CancelID.saveDebounce, cancelInFlight: true) {
//          try await self.clock.sleep(for: .seconds(1))
//          try await self.saveData(data, .syncUps)
//        }
//      } catch: { _, _ in
//      }
//    }
  }

  @Reducer
  struct Path {
    @ObservableState
    enum State: Equatable {
      case detail(SyncUpDetail.State)
      case meeting(Meeting, syncUp: SyncUp)
      case record(RecordMeeting.State)
    }

    enum Action {
      case detail(SyncUpDetail.Action)
      case record(RecordMeeting.Action)
    }

    var body: some Reducer<State, Action> {
      Scope(state: \.detail, action: \.detail) {
        SyncUpDetail()
      }
      Scope(state: \.record, action: \.record) {
        RecordMeeting()
      }
    }
  }
}

struct AppView: View {
  @Bindable var store: StoreOf<AppFeature>

  var body: some View {
    NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
      SyncUpsListView(
        store: store.scope(state: \.syncUpsList, action: \.syncUpsList)
      )
    } destination: { store in
      switch store.state {
      case .detail:
        if let store = store.scope(state: \.detail, action: \.detail) {
          SyncUpDetailView(store: store)
        }
      case let .meeting(meeting, syncUp: syncUp):
        MeetingView(meeting: meeting, syncUp: syncUp)
      case .record:
        if let store = store.scope(state: \.record, action: \.record) {
          RecordMeetingView(store: store)
        }
      }
    }
  }
}

extension URL {
  static let syncUps = Self.documentsDirectory.appending(component: "sync-ups.json")
}

import SwiftData
private enum ModelContainerKey: TestDependencyKey {
  static var testValue = try! ModelContainer(
    for: Schema(),
    configurations: []
  )
}
extension DependencyValues {
  var modelContainer: ModelContainer {
    get { self[ModelContainerKey.self] }
    set { self[ModelContainerKey.self] = newValue }
  }
}
