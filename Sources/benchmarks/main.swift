import Benchmark
import Combine
import ComposableArchitecture
import RefactoredComposableArchitecture

let store1 = ComposableArchitecture.Store(
  initialState: initialState,
  reducer: ComposableArchitecture.Reducer<State, Void, Void> {
    reducer(state: &$0, action: $1, environment: $2)
    return .none
  },
  environment: ()
)
var store2: ComposableArchitecture.Store<State, Void>!
var store3: ComposableArchitecture.Store<State, Void>!
var store4: ComposableArchitecture.Store<State, Void>!
var store5: ComposableArchitecture.Store<State, Void>!
var viewStore1: ComposableArchitecture.ViewStore<ViewState, Void>!
var viewStore2: ComposableArchitecture.ViewStore<ViewState, Void>!
var viewStore3: ComposableArchitecture.ViewStore<ViewState, Void>!
var viewStore4: ComposableArchitecture.ViewStore<ViewState, Void>!
var viewStore5: ComposableArchitecture.ViewStore<ViewState, Void>!

let refactoredStore1 = RefactoredComposableArchitecture.Store(
  initialState: initialState,
  reducer: RefactoredComposableArchitecture.Reducer<State, Void, Void> {
    reducer(state: &$0, action: $1, environment: $2)
    return .none
  },
  environment: ()
)
var refactoredStore2: RefactoredComposableArchitecture.Store<State, Void>!
var refactoredStore3: RefactoredComposableArchitecture.Store<State, Void>!
var refactoredStore4: RefactoredComposableArchitecture.Store<State, Void>!
var refactoredStore5: RefactoredComposableArchitecture.Store<State, Void>!
var refactoredViewStore1: RefactoredComposableArchitecture.ViewStore<ViewState, Void>!
var refactoredViewStore2: RefactoredComposableArchitecture.ViewStore<ViewState, Void>!
var refactoredViewStore3: RefactoredComposableArchitecture.ViewStore<ViewState, Void>!
var refactoredViewStore4: RefactoredComposableArchitecture.ViewStore<ViewState, Void>!
var refactoredViewStore5: RefactoredComposableArchitecture.ViewStore<ViewState, Void>!

let suite = BenchmarkSuite(name: ".send")
suite.register(
  benchmark: Benchmarking(
    name: "Original",
    run: {
      viewStore1.send(())
      viewStore2.send(())
      viewStore3.send(())
      viewStore4.send(())
      viewStore5.send(())
    },
    setUp: {
      store2 = store1.scope(state: \.sub[0])
      store3 = store2.scope(state: \.sub[0])
      store4 = store3.scope(state: \.sub[0])
      store5 = store4.scope(state: \.sub[0])
      viewStore1 = ViewStore(store1.scope(state: ViewState.init))
      viewStore2 = ViewStore(store2.scope(state: ViewState.init))
      viewStore3 = ViewStore(store3.scope(state: ViewState.init))
      viewStore4 = ViewStore(store4.scope(state: ViewState.init))
      viewStore5 = ViewStore(store5.scope(state: ViewState.init))
    }
  )
)
suite.register(
  benchmark: Benchmarking(
    name: "Refactored",
    run: {
      refactoredViewStore1.send(())
      refactoredViewStore2.send(())
      refactoredViewStore3.send(())
      refactoredViewStore4.send(())
      refactoredViewStore5.send(())
    },
    setUp: {
      refactoredStore2 = refactoredStore1.scope(state: \.sub[0])
      refactoredStore3 = refactoredStore2.scope(state: \.sub[0])
      refactoredStore4 = refactoredStore3.scope(state: \.sub[0])
      refactoredStore5 = refactoredStore4.scope(state: \.sub[0])
      refactoredViewStore1 = ViewStore(refactoredStore1.scope(state: ViewState.init))
      refactoredViewStore2 = ViewStore(refactoredStore2.scope(state: ViewState.init))
      refactoredViewStore3 = ViewStore(refactoredStore3.scope(state: ViewState.init))
      refactoredViewStore4 = ViewStore(refactoredStore4.scope(state: ViewState.init))
      refactoredViewStore5 = ViewStore(refactoredStore5.scope(state: ViewState.init))
    }
  )
)

main(
  [suite,],
  settings: [TimeUnit(.ms)]
)
