import ComposableArchitecture
import SwiftUI

@main
struct CaseStudiesApp: App {
  var body: some Scene {
    WindowGroup {
      RootView(
        store: Store(
          initialState: RootState(),
          reducer:
            rootReducer
            .debug()
            .signpost(),
          environment: .live
        )
      )
    }
  }
}
