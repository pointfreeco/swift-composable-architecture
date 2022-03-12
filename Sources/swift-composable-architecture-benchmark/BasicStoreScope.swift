import Benchmark
import ComposableArchitecture

let basicStoreScopeSuite = BenchmarkSuite(name: "Basic Store Scope") { suite in
  let counterReducer = Reducer<Int, Void, Void> { state, _, _ in
    state &+= 1
    return .none
  }

  let store1 = Store(initialState: 0, reducer: counterReducer, environment: ())
  let store2 = store1.scope { $0 }
  let store3 = store2.scope { $0 }
  let store4 = store3.scope { $0 }

  let viewStore1 = ViewStore(store1)
  let viewStore2 = ViewStore(store2)
  let viewStore3 = ViewStore(store3)
  let viewStore4 = ViewStore(store4)

  suite.benchmark("Depth 1") {
    viewStore1.send(())
  }

  suite.benchmark("Depth 2") {
    viewStore2.send(())
  }
  suite.benchmark("Depth 3") {
    viewStore3.send(())
  }
  suite.benchmark("Depth 4") {
    viewStore4.send(())
  }
}
