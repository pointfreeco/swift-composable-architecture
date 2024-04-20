import ComposableArchitecture
import GRDB
import SwiftUI

@Reducer
struct AppFeature {
  @Reducer(state: .equatable)
  enum Path {
    case detail(SyncUpDetail)
    case meeting(Meeting, syncUp: SyncUp)
    case record(RecordMeeting)
  }

  @ObservableState
  struct State: Equatable {
    var path = StackState<Path.State>()
    var syncUpsList = SyncUpsList.State()
  }

  enum Action {
    case `init`
    case path(StackActionOf<Path>)
    case syncUpsList(SyncUpsList.Action)
  }

  @Dependency(\.defaultDatabaseQueue) var databaseQueue
  @Dependency(\.date.now) var now
  @Dependency(\.uuid) var uuid

  var body: some ReducerOf<Self> {
    Scope(state: \.syncUpsList, action: \.syncUpsList) {
      SyncUpsList()
    }
    Reduce { state, action in
      switch action {
      case .`init`:
        return .run { _ in
          var migrator = DatabaseMigrator()
          migrator.registerMigration("Create sync-ups") { db in
            try db.create(table: SyncUp.databaseTableName) { t in
              t.autoIncrementedPrimaryKey("id")
              t.column("attendees", .jsonText)
              t.column("meetings", .jsonText)
              t.column("minutes", .integer)
              t.column("theme", .text)
              t.column("title", .text)
            }
          }
          migrator.registerMigration("Create meetings") { db in
            try db.create(table: Meeting.databaseTableName) { t in
              t.autoIncrementedPrimaryKey("id")
              t.column("date", .datetime)
              t.column("syncUpID", .integer)
              t.column("transcript", .text)
            }
          }
          try migrator.migrate(databaseQueue)
        }

      case let .path(.element(id, .detail(.delegate(delegateAction)))):
        switch delegateAction {
        case .startMeeting:
          let detailState = state.path[id: id]!.detail!
          state.path.append(.record(RecordMeeting.State(syncUp: detailState.$syncUp)))
          return .none
        }

      case .path:
        return .none

      case let .syncUpsList(.delegate(action)):
        switch action {
        case let .goToSyncUp($syncUp):
          state.path.append(.detail(SyncUpDetail.State(syncUp: $syncUp)))
          return .none
        }

      case .syncUpsList:
        return .none
      }
    }
    .forEach(\.path, action: \.path)
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
      switch store.case {
      case let .detail(store):
        SyncUpDetailView(store: store)
      case let .meeting(meeting, syncUp):
        MeetingView(meeting: meeting, syncUp: syncUp)
      case let .record(store):
        RecordMeetingView(store: store)
      }
    }
  }
}

#Preview {
  @SharedReader(.syncUps) var syncUps: IdentifiedArrayOf<SyncUp> = [
    .mock,
    .productMock,
    .engineeringMock
  ]
  return AppView(
    store: Store(initialState: AppFeature.State()) {
      AppFeature()
    }
  )
}
