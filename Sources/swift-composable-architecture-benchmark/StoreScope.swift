import Benchmark
import ComposableArchitecture

private struct Counter: ReducerProtocol {
  typealias State = Int
  typealias Action = Bool
  func reduce(into state: inout Int, action: Bool) -> EffectTask<Bool> {
    if action {
      state += 1
      return .none
    } else {
      state -= 1
      return .none
    }
  }
}

let storeScopeSuite = BenchmarkSuite(name: "Store scoping") { suite in
  var store = Store(initialState: 0, reducer: Counter())
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
