import ComposableArchitecture
import SwiftUI

@main
struct StandupsApp: App {
  var body: some Scene {
    WindowGroup {
      if !_XCTIsTesting {
        StandupsListView(
          store: Store(
            initialState: StandupsList.State(),
            reducer: StandupsList()
              ._printChanges()
          )
        )
      }
    }
  }
}
