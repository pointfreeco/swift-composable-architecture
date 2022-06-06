import Benchmark
import ComposableArchitecture

let scopingSuite = BenchmarkSuite(name: "Scoping") { suite in
  do {
    var store: Store<BaseState, BaseAction>?
    suite.benchmark("Standalone.Instantiate") {
      store = .init(initialState: .init(), reducer: baseReducer, environment: .init())
    } tearDown: {
      precondition(store != nil)
    }
  }

  do {
    let store = Store(initialState: .init(), reducer: rootReducer, environment: .init())
    var scoped: Store<BaseState, BaseAction>?
    suite.benchmark("Scoped.Instantiate") {
      scoped = store.scope(state: \.base, action: RootAction.base)
    } tearDown: {
      precondition(scoped != nil)
    }
  }

  do {
    let store = Store(initialState: .init(), reducer: baseReducer, environment: .init())
    let viewStore = ViewStore(store)

    suite.benchmark("Standalone.ReduceAction") {
      viewStore.send(.setInteger(1))
    } tearDown: {
      precondition(viewStore.integer == 1)
    }
  }

  do {
    let store = Store(initialState: .init(), reducer: rootReducer, environment: .init())
    let scoped = store.scope(state: \.base, action: RootAction.base)
    let viewStore = ViewStore(scoped)
    suite.benchmark("Scoped.ReduceAction") {
      viewStore.send(.setInteger(1))
    } tearDown: {
      precondition(viewStore.integer == 1)
    }
  }
  
  do {
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

    let viewStore1 = ViewStore(store1)
    let viewStore2 = ViewStore(store2)
    let viewStore3 = ViewStore(store3)
    let viewStore4 = ViewStore(store4)

    suite.benchmark("Chain.0") {
      viewStore1.send(true)
    }
    viewStore1.send(false)

    suite.benchmark("Chain.1") {
      viewStore2.send(true)
    }
    viewStore1.send(false)

    suite.benchmark("Chain.2") {
      viewStore3.send(true)
    }
    viewStore1.send(false)

    suite.benchmark("Chain.2") {
      viewStore4.send(true)
    }
  }
}
