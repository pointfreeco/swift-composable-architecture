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
  @Shared(.syncUps) var syncUps = [.mock]
  NavigationStack {
    SyncUpsListView(
      store: Store(
        initialState: SyncUpsList.State()
      ) {
        SyncUpsList()
          ._printChanges()
      }
    )
  }
}