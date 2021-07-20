import Benchmark
import ComposableArchitecture

let counterReducer = Reducer<Int, Bool, Void> { state, action, _ in
  if action {
    state += 1
  } else {
    state = 0
  }
  return .none
}

let old = BenchmarkSuite(name: "Store") {
  let store1 = Store(initialState: 0, reducer: counterReducer, environment: ())
  let store2 = store1.scope { $0 }
  let store3 = store2.scope { $0 }
  let store4 = store3.scope { $0 }

  let viewStore1 = ViewStore(store1)
  let viewStore2 = ViewStore(store2)
  let viewStore3 = ViewStore(store3)
  let viewStore4 = ViewStore(store4)

  $0.benchmark("Scoping (1)") {
    viewStore1.send(true)
  }
  viewStore1.send(false)

  $0.benchmark("Scoping (2)") {
    viewStore2.send(true)
  }
  viewStore1.send(false)

  $0.benchmark("Scoping (3)") {
    viewStore3.send(true)
  }
  viewStore1.send(false)

  $0.benchmark("Scoping (4)") {
    viewStore4.send(true)
  }
}

let new = BenchmarkSuite(name: "_Store") {
  let store1 = _Store(initialState: 0, reducer: counterReducer, environment: ())
  let store2 = store1.scope { $0 }
  let store3 = store2.scope { $0 }
  let store4 = store3.scope { $0 }

  let viewStore1 = _ViewStore(store1)
  let viewStore2 = _ViewStore(store2)
  let viewStore3 = _ViewStore(store3)
  let viewStore4 = _ViewStore(store4)

  $0.benchmark("Scoping (1)") {
    viewStore1.send(true)
  }
  viewStore1.send(false)

  $0.benchmark("Scoping (2)") {
    viewStore2.send(true)
  }
  viewStore1.send(false)

  $0.benchmark("Scoping (3)") {
    viewStore3.send(true)
  }
  viewStore1.send(false)

  $0.benchmark("Scoping (4)") {
    viewStore4.send(true)
  }
}


Benchmark.main([old, new])
