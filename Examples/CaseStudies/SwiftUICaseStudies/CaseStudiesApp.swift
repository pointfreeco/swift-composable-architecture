import ComposableArchitecture
import SwiftUI

@main
struct CaseStudiesApp: App {
  var body: some Scene {
    WindowGroup {
      RootView(
        store: Store(
          initialState: Root.State(),
          reducer: Root()
            .signpost()
            ._printChanges()
        )
      )
    }
  }
}
