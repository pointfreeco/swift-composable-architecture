import Benchmark
import ComposableArchitecture

let storeScopeSuite = BenchmarkSuite(name: "Store scoping") { suite in
  let counterReducer = Reducer<Int, Bool, Void> { state, action, _ in
    if action {
      state += 1
      return .none
    } else {
      state -= 1
      return .none
    }
  }
  var store = Store(initialState: 0, reducer: counterReducer, environment: ())
  var viewStores: [ViewStore<Int, Bool>] = [ViewStore(store)]
  for _ in 1...4 {
    store = store.scope(state: { $0 })
    viewStores.append(ViewStore(store))
  }
  let lastViewStore = viewStores.last!

  suite.benchmark("Nested store") {
    lastViewStore.send(true)
  }
}
