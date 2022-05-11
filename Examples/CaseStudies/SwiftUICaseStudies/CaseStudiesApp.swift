import ComposableArchitecture
import SwiftUI

@main
struct CaseStudiesApp: App {
  var body: some Scene {
    WindowGroup {
      EffectsBasicsView(
        store: Store(
          initialState: EffectsBasicsState(),
          reducer: EffectsBasicsReducer()
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
