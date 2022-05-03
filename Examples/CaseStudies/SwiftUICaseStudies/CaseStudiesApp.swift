import ComposableArchitecture
import SwiftUI

struct TwoCountersReducer: ReducerProtocol {
  var body: some ReducerProtocol<TwoCountersState, TwoCountersAction> {
    Scope(state: \.counter1, action: /TwoCountersAction.counter1) {
      CounterReducer()
    }
    Scope(state: \.counter2, action: /TwoCountersAction.counter2) {
      CounterReducer()
    }
  }
}

@main
struct CaseStudiesApp: App {
  var body: some Scene {
    WindowGroup {
      TwoCountersView(
        store: Store(
          initialState: TwoCountersState(),
          reducer: TwoCountersReducer()
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
