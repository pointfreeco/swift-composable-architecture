import Benchmark
import ComposableArchitecture


let compositionSuite = BenchmarkSuite(name: "Composition") {
  $0.benchmarkNormalStore(label: "Reference", reducer: baseReducer)
  // Ideally, should be the closest possible to "Base"
  $0.benchmarkNormalStore(label: "Combined", reducer: .combine(baseReducer))
  // Ideally, should be the closest possible to "Base"
  $0.benchmarkNormalStore(label: "CombinedWithEmpty", reducer: .combine(baseReducer, .empty))
}

extension BenchmarkSuite {
  func benchmarkNormalStore(label: String, reducer: Reducer<BaseState, BaseAction, BaseEnvironment>) {
    var _store: Store<BaseState, BaseAction>?
    self.benchmark("\(label).Instantiate") {
      _store = .init(
        initialState: .init(),
        reducer: reducer,
        environment: .init()
      )
    } setUp: {
      _store = nil
    } tearDown: {
      precondition(_store != nil)
    }

    let store = Store(
      initialState: .init(),
      reducer: reducer,
      environment: .init()
    )
    let viewStore = ViewStore(store)

    self.benchmark("\(label).ReduceAction") {
      viewStore.send(.reset)
    } tearDown: {
      precondition(viewStore.string == "")
    }
    
    self.benchmark("\(label).ReduceIndirectAction") {
      viewStore.send(.reset)
    } tearDown: {
      precondition(viewStore.string == "")
    }
    
    self.benchmark("\(label).ReduceIndirectActionViaEnvironment") {
      viewStore.send(.indirectResetViaEnvironment)
    } tearDown: {
      precondition(viewStore.string == "")
    }
  }
}
