import ComposableArchitecture
import SwiftUI

@main
struct CaseStudiesApp: App {
  var body: some Scene {
    WindowGroup {
//      RootView()
      ParentView2(
        store: Store(initialState: Parent2.State()) {
          Parent2()
        }
      )
//      ParentView(
//        store: Store(initialState: Parent.State()) {
//          Parent()
//        }
//      )
//      DragDistanceView(
//        store: Store(initialState: DragDistance.State()) {
//          DragDistance()
//        }
//      )
//      VanillaDragDistanceView()
    }
  }
}
