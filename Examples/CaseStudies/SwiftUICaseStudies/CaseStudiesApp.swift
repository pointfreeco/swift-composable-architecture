import ComposableArchitecture
import SwiftUI

@main
struct CaseStudiesApp: App {
  var body: some Scene {
    WindowGroup {
      RootView(
        store: Store(initialState: Root.State()) {
          Root()
            .signpost()
            ._printChanges()
        }
      )
    }
  }
}
