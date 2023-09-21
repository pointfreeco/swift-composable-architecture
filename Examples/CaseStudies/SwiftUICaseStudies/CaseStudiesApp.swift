import ComposableArchitecture
import SwiftUI

@main
struct CaseStudiesApp: App {
  var body: some Scene {
    WindowGroup {
//      NavigationDemoView(
//        store: Store(initialState: NavigationDemo.State()) {
//          NavigationDemo()
//            ._printChanges()
//        }
//      )
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
