import SwiftUI

@main
struct CaseStudiesApp: App {
  var body: some Scene {
    WindowGroup {
      NavigationStackView(
        store: .init(
          initialState: .init(
            path: [
              // TODO: doesn't work due to bug in SwiftUI that causes navigation path binding to immediately be written with an empty array.
//              0: .screenA(.init()),
//              1: .screenA(.init(count: 100)),
            ]
          ),
          reducer: navigationStackReducer,
          environment: .live
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
