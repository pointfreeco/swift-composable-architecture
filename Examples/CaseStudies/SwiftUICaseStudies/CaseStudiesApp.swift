import ComposableArchitecture
import SwiftUI

@main
struct CaseStudiesApp: App {
  var body: some Scene {
    WindowGroup {
//      NavigationView {
//        NavigationLink("Effect basics") {
//          EffectsBasicsView(
//            store: Store(
//              initialState: EffectsBasicsState(count: 50_000),
//              reducer: effectsBasicsReducer,
//              environment: EffectsBasicsEnvironment(fact: .live, mainQueue: .main)
//            )
//          )
//        }
//      }
      RootView(
        store: Store(
          initialState: RootState(),
          reducer: rootReducer,
          environment: .live
        )
      )
    }
  }
}
