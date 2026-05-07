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
      path: $store.scope(\.path, action: \.path)
    ) {
      SyncUpsListView(
        store: store.scope(\.syncUpsList, action: \.syncUpsList)
      )
    } destination: { store in
      switch store.case {
      case let .detail(detailStore):
        
      }
    }
  }
}
