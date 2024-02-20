import ComposableArchitecture
import SwiftUI

@main
struct SyncUpsApp: App {
  let store = Store(initialState: AppFeature.State()) {
    AppFeature()
      ._printChanges()
  }

  var body: some Scene {
    WindowGroup {
      if _XCTIsTesting || ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
        // NB: Don't run application when testing so that it doesn't interfere with tests, or in
        //     previews so that it doesn't interfere with previews.
        EmptyView()
      } else {
        //AppView(store: store)
      }
    }
  }
}
