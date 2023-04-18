import ComposableArchitecture
import SwiftUI

@main
struct StandupsApp: App {
  var body: some Scene {
    WindowGroup {
      if !_XCTIsTesting {
        AppView(
          store: Store(
            initialState: AppFeature.State(),
            reducer: AppFeature()
              ._printChanges()
          )
        )
      }
    }
  }
}
