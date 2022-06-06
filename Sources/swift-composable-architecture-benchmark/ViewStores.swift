import Benchmark
import ComposableArchitecture

#if canImport(SwiftUI)
import SwiftUI
#endif

let viewStoreSuite = BenchmarkSuite(name: "ViewStore") { suite in
  do {
    let store = Store(initialState: .init(), reducer: baseReducer, environment: .init())
    var viewStore: ViewStore<BaseState, BaseAction>?
    suite.benchmark("Intantiate") {
      viewStore = ViewStore(store)
    } tearDown: {
      precondition(viewStore != nil)
    }
  }
  
  #if canImport(SwiftUI)
  do {
    let store = Store(initialState: .init(), reducer: baseReducer, environment: .init())
    var view: WithViewStore<BaseState, BaseAction, Color>?
    let color = Color.clear
    var body: Color?
    suite.benchmark("Intantiate.WithViewStore->Body") {
      body = WithViewStore(store) { _ in
        color
      }.body
    } tearDown: {
      precondition(body != nil)
    }
  }
  #endif
}
