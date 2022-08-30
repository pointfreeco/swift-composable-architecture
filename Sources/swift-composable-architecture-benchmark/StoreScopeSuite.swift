import Benchmark
import ComposableArchitecture

//
//let counterReducer = Reducer<Int, Bool, Void> { state, action, _ in
//  if action {
//    state += 1
//  } else {
//    state = 0
//  }
//  return .none
//}
//
//let store1 = Store(initialState: 0, reducer: counterReducer, environment: ())
//let store2 = store1.scope { $0 }
//let store3 = store2.scope { $0 }
//let store4 = store3.scope { $0 }
//
//let viewStore1 = ViewStore(store1)
//let viewStore2 = ViewStore(store2)
//let viewStore3 = ViewStore(store3)
//let viewStore4 = ViewStore(store4)
//
//benchmark("Scoping (1)") {
//  viewStore1.send(true)
//}
//viewStore1.send(false)
//
//benchmark("Scoping (2)") {
//  viewStore2.send(true)
//}
//viewStore1.send(false)
//
//benchmark("Scoping (3)") {
//  viewStore3.send(true)
//}
//viewStore1.send(false)
//
//benchmark("Scoping (4)") {
//  viewStore4.send(true)
//}

let storeScopeSuite = BenchmarkSuite(name: "Store scoping") { suite in
  var counterReducer = Reducer<Int, Bool, Void> { state, action, _ in
    if action {
      state += 1
      return .none
    } else {
      state -= 1
      return .none
    }
  }
  for _ in 1...10 {
    counterReducer = counterReducer.pullback(state: \.self, action: /.self, environment: { $0 })
  }
  var store = Store(initialState: 0, reducer: counterReducer, environment: ())
  var viewStores: [ViewStore<Int, Bool>] = []
  for _ in 1...10 {
    store = store.scope(state: { $0 })
    viewStores.append(ViewStore(store))
  }

  suite.benchmark("Nested") {
    for viewStore in viewStores {
      viewStore.send(true)
      viewStore.send(false)
    }
  }
}
