import SwiftUI

@main
struct CaseStudiesApp: App {
  var body: some Scene {
    WindowGroup {
      RootView(
        store: .init(
          initialState: RootState(),
          reducer: rootReducer,
          environment: .live
        )
      )
    }
  }
}
