import ComposableArchitecture
import SwiftUI

@main
struct SearchApp: App {
  var body: some Scene {
    WindowGroup {
      SearchView(
        store: Store(
          initialState: Search.State(),
          reducer: Search()._printChanges()
        )
      )
    }
  }
}
