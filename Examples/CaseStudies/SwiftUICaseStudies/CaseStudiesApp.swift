import ComposableArchitecture
import SwiftUI

@main
struct CaseStudiesApp: App {
  var body: some Scene {
    WindowGroup {
      SheetDemoView(store: Store(initialState: SheetDemo.State(), reducer: SheetDemo().debug()))
//      RootView(
//        store: Store(
//          initialState: Root.State(),
//          reducer: Root()
//            .debug()
//            .signpost()
//        )
//      )
    }
  }
}
