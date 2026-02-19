import ComposableArchitecture
import SwiftUI

@Reducer
struct AppFeature {
  @Reducer
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
    case path(StackActionOf<Path>)
    case syncUpsList(SyncUpsList.Action)
  }

  @Dependency(\.date.now) var now
  @Dependency(\.uuid) var uuid

  var body: some ReducerOf<Self> {
    Scope(state: \.syncUpsList, action: \.syncUpsList) {
      SyncUpsList()
    }
    Reduce { state, action in
      switch action {
      case .path(.element(_, .detail(.delegate(let delegateAction)))):
        switch delegateAction {
        case .startMeeting(let sharedSyncUp):
          state.path.append(.record(RecordMeeting.State(syncUp: sharedSyncUp)))
          return .none
        }

      case .path:
        return .none

      case .syncUpsList:
        return .none
      }
    }
    .forEach(\.path, action: \.path)
  }
}
extension AppFeature.Path.State: Equatable {}

struct AppView: View {
  @Bindable var store: StoreOf<AppFeature>

  var body: some View {
    NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
      SyncUpsListView(store: store.scope(state: \.syncUpsList, action: \.syncUpsList))
    } destination: { store in
      switch store.case {
      case .detail(let store):
        SyncUpDetailView(store: store)
      case .meeting(let meeting, let syncUp):
        MeetingView(meeting: meeting, syncUp: syncUp)
      case .record(let store):
        RecordMeetingView(store: store)
      }
    }
  }
}

#Preview {
  @Shared(.syncUps) var syncUps = [
    .mock,
    .productMock,
    .engineeringMock,
  ]
  AppView(
    store: Store(initialState: AppFeature.State()) {
      AppFeature()
    }
  )
}
