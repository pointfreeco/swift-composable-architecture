import ComposableArchitecture
import SwiftUI

@Reducer
struct App {
  // ...
}

struct AppView: View {
  // ...
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
