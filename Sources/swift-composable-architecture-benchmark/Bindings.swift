import Benchmark
import ComposableArchitecture

let bindingSuite = BenchmarkSuite(name: "Bindings") { suite in
  do {
    let store = Store(
      initialState: .init(),
      reducer: baseReducer,
      environment: .init())
    let viewStore = ViewStore(store)

    suite.benchmark("AdHoc") {
      viewStore.send(.setInteger(10))
    } tearDown: {
      precondition(viewStore.integer == 10)
    }
  }
  
  do {
    let store = Store(
      initialState: .init(),
      reducer: Reducer<BindableBaseState, BindableBaseAction, BaseEnvironment> { _, _, _ in .none }
        .binding(),
      environment: .init())
    let viewStore = ViewStore(store)

    suite.benchmark("Binding") {
      viewStore.send(.set(\.$integer, 10))
    } tearDown: {
      precondition(viewStore.integer == 10)
    }
  }
}
