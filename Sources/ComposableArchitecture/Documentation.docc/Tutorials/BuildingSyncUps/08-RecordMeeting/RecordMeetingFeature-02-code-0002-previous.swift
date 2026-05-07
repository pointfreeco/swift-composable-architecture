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
      path: $store.scope(\.path, action: \.path)
    ) {
      SyncUpsListView(
        store: store.scope(\.syncUpsList, action: \.syncUpsList)
      )
    } destination: { store in
      switch store.case {
      case let .detail(detailStore):
        SyncUpDetailView(store: detailStore)
      case let .meeting(meeting, syncUp: syncUp):
        MeetingView(meeting: meeting, syncUp: syncUp)
      }
    }
  }
}
