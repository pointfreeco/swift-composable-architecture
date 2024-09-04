import ComposableArchitecture
import SwiftUI

@Reducer
struct AppFeature {
  // ...
}

struct AppView: View {
  @Bindable var store: StoreOf<AppFeature>

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

#Preview {
  AppView(
    store: Store(
      initialState: AppFeature.State(
        syncUpsList: SyncUpsList.State()
      )
    ) {
      AppFeature()
    }
  )
}
