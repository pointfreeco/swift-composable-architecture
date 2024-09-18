import ComposableArchitecture
import SwiftUI

@main
struct CaseStudiesApp: App {
  @MainActor static let store = Store(
    initialState: ListFeature.State(
      children: IdentifiedArray(uniqueElements: (1...1_000).map { idx in
        ChildFeature.State(count: idx)
      })
    )
  ) {
    ListFeature()
      //._printChanges()
  }

  var body: some Scene {
    WindowGroup {
//      ListView(
//        store: Self.store
//      )

      DetachedNavigationRoot(
        store: Store(initialState: DetachedNavigationFeature.State()) {
          DetachedNavigationFeature()
            ._printChanges()
        }
      )

//      RootView()
//      ParentView2(
//        store: Store(initialState: Parent2.State()) {
//          Parent2()
//        }
//      )
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
