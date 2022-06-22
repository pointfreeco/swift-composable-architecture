import ComposableArchitecture
import SwiftUI

@main
struct CaseStudiesApp: App {
  var body: some Scene {
    WindowGroup {
//      RootView(
//        store: Store(
//          initialState: Root.State(),
//          reducer: Root()
//            .debug()
//            .signpost()
//        )
//      )

      NavigationDemoView(
        store: Store(
          initialState: NavigationDemo.State(),
          reducer: NavigationDemo()
            .debug()
        )
      )
    }
  }
}
