import ComposableArchitecture
import SwiftUI

struct TwoCountersReducer: ReducerProtocol {
  var body: some ReducerProtocol<TwoCountersState, TwoCountersAction> {
    CounterReducer()
      .pullback(state: \.counter1, action: /TwoCountersAction.counter1)

    Scope(state: \.counter2, action: /TwoCountersAction.counter2) {
      CounterReducer()
    }
  }
}

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
