import ComposableArchitecture
import SwiftUI

@Reducer
struct App {
  // ...
}

struct AppView: View {
  @Bindable var store: StoreOf<App>

  var body: some View {
    NavigationStack(
      path: $store.scope(state: \.path, action: \.path)
    ) {
      SyncUpsListView(
        store: store.scope(state: \.syncUpsList, action: \.syncUpsList)
      )
    } destination: { store in
      switch store.case {
      case let .detail(detailStore):
        SyncUpDetailView(store: detailStore)
      case let .meeting(meeting, syncUp: syncUp):
        MeetingView(meeting: meeting, syncUp: syncUp)
      case let .record(recordStore):
        RecordMeetingView(store: recordStore)
      }
    }
  }
}

#Preview {
  AppView(
    store: Store(
      initialState: App.State(
        syncUpsList: SyncUpsList.State()
      )
    ) {
      App()
    }
  )
}
