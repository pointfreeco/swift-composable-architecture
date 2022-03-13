import Benchmark
import ComposableArchitecture

let reducerSuite = BenchmarkSuite(name: "Reducer") { suite in

  let reducer = Reducer<Int, Void, Void> { state, _, _ in
    state &+= 1
    return .none
  }

  do {
    let reducers = Reducer<Int, Void, Void>.combine([reducer, reducer])

    let store = Store(initialState: 0, reducer: reducers, environment: ())
    let viewStore = ViewStore(store)

    suite.benchmark("combine([a, b])") {
      viewStore.send(())
    }
  }

  do {
    let reducers = Reducer<Int, Void, Void>.combine(reducer, reducer)

    let store = Store(initialState: 0, reducer: reducers, environment: ())
    let viewStore = ViewStore(store)

    suite.benchmark("combine(a, b)") {
      viewStore.send(())
    }
  }
  
  do {
    let reducers = Reducer<Int, Void, Void>
      .combine([reducer, reducer, reducer, reducer, reducer, reducer, reducer, reducer])

    let store = Store(initialState: 0, reducer: reducers, environment: ())
    let viewStore = ViewStore(store)

    suite.benchmark("combine([a, b, c, d, e, f, g, h])") {
      viewStore.send(())
    }
  }

  do {
    let reducers = Reducer<Int, Void, Void>
      .combine(reducer, reducer, reducer, reducer, reducer, reducer, reducer, reducer)

    let store = Store(initialState: 0, reducer: reducers, environment: ())
    let viewStore = ViewStore(store)

    suite.benchmark("combine(a, b, c, d, e, f, g, h)") {
      viewStore.send(())
    }
  }
}
