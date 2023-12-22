import Benchmark
import ComposableArchitecture

#if swift(>=5.9)
  @Reducer
  private struct Counter {
    typealias State = Int
    typealias Action = Bool
    var body: some Reducer<State, Action> {
      Reduce { state, action in
        if action {
          state += 1
          return .none
        } else {
          state -= 1
          return .none
        }
      }
    }
  }
#endif

let storeScopeSuite = BenchmarkSuite(name: "Store scoping") { suite in
  #if swift(>=5.9)
    var store = Store(initialState: 0) { Counter() }
    var viewStores: [ViewStore<Int, Bool>] = [ViewStore(store, observe: { $0 })]
    for _ in 1...4 {
      store = store.scope(state: { $0 }, action: { $0 })
      viewStores.append(ViewStore(store, observe: { $0 }))
    }
    let lastViewStore = viewStores.last!

    suite.benchmark("Nested store") {
      lastViewStore.send(true)
    }
  #endif
}
