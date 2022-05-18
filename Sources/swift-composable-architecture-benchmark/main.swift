import Benchmark
import ComposableArchitecture


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
do {
  struct State: Equatable {
    @BindableState var value: Int = 0
  }

  enum Action: BindableAction {
    case binding(BindingAction<State>)
  }

  do {
    let store = Store(initialState: .init(),
                      reducer: EmptyReducer<State, Action>().binding())
    let viewStore = ViewStore(store)
    benchmark("reduce") {
      viewStore.send(.set(\.$value, 1))
    }
  }
  
  do {
    let store = Store(initialState: .init(),
                      reducer: EmptyReducer<State, Action>().bindingWithBody())
    let viewStore = ViewStore(store)
    benchmark("body") {
      viewStore.send(.set(\.$value, 1))
    }
  }
}

Benchmark.main()
