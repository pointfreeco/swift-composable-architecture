import ComposableArchitecture
import SwiftUI

@main
struct CaseStudiesApp: App {
  var body: some Scene {
    WindowGroup {
//      RootView(
//        store: .init(
//          initialState: .init(),
//          reducer: Root()
//            .debug()
//            .signpost()
//        )
//      )
      NavigationStackView(
        store: .init(
          initialState: .init(),
          reducer: NavigationStackDemo()
        )
      )

//      RootView(
//        store: .init(
//          initialState: RootState(),
//          reducer: rootReducer,
//          environment: .live
//        )
//      )
    }
  }
}
