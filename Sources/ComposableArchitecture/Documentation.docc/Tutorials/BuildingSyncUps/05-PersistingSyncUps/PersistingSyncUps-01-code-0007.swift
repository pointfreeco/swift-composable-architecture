import ComposableArchitecture
import SwiftUI

@main
struct SyncUpsApp: App {
  @MainActor
  static let store = Store(initialState: SyncUpsList.State()) {
    SyncUpsList()
  }

  var body: some Scene {
    WindowGroup {
      NavigationStack {
        SyncUpsListView(store: Self.store)
      }
    }
  }
}
