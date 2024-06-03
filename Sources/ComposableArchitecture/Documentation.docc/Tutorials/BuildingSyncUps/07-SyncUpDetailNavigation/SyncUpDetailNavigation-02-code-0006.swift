import ComposableArchitecture
import SwiftUI

@Reducer
struct AppReducer {
  // ...
}

struct AppView: View {
  @Bindable var store: StoreOf<AppReducer>

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
      }
    }
  }
}
