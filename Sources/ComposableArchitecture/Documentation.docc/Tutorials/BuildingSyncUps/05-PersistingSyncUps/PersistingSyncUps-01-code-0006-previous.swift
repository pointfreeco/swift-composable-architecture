import ComposableArchitecture
import SwiftUI

@Reducer
struct SyncUpsList {
  // ...
}

struct SyncUpsListView: View {
  // ...
}

#Preview {
  NavigationStack {
    SyncUpsListView(
      store: Store(
        initialState: SyncUpsList.State(
          syncUps: [.mock]
        )
      ) {
        SyncUpsList()
          ._printChanges()
      }
    )
  }
}