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

let store1 = Store(initialState: 0, reducer: counterReducer, environment: ())
let store2 = store1.scope { $0 }
let store3 = store2.scope { $0 }
let store4 = store3.scope { $0 }

let viewStore1 = store1.viewStore
let viewStore2 = store2.viewStore
let viewStore3 = store3.viewStore
let viewStore4 = store4.viewStore

benchmark("Scoping (1)") {
  viewStore1.send(true)
}
viewStore1.send(false)

benchmark("Scoping (2)") {
  viewStore2.send(true)
}
viewStore1.send(false)

benchmark("Scoping (3)") {
  viewStore3.send(true)
}
viewStore1.send(false)

benchmark("Scoping (4)") {
  viewStore4.send(true)
}

Benchmark.main()
