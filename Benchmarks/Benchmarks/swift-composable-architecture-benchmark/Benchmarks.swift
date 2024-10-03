import Benchmark
import ComposableArchitecture
import Foundation

private func initialState(for nesting: Int) -> Feature.State {
  (1..<nesting).reduce(into: Feature.State()) { state, _ in state = Feature.State(child: state) }
}

@MainActor
private func rootStore(for nesting: Int) -> StoreOf<Feature> {
  Store(initialState: initialState(for: nesting)) { Feature() }
}

@MainActor
private func scopedStore(for nesting: Int, from root: StoreOf<Feature>? = nil) -> StoreOf<Feature> {
  (1..<nesting).reduce(into: root ?? rootStore(for: nesting)) { store, _ in
    store = store.scope(state: \.child, action: \.child.presented)!
  }
}

let benchmarks = { @Sendable in
  Benchmark("Store.Scope") { @MainActor benchmark async in
    benchmark.startMeasurement()
    _ = scopedStore(for: 1)
  }

  Benchmark("Store.Send") { @MainActor benchmark async in
    let store = scopedStore(for: 1)
    benchmark.startMeasurement()
    blackHole(store.send(.incrementButtonTapped))
  }

  Benchmark("Store.Access") { @MainActor benchmark async in
    let store = scopedStore(for: 1)
    benchmark.startMeasurement()
    blackHole(store.state)
  }

  Benchmark("NestedStore.Scope") { @MainActor benchmark async in
    benchmark.startMeasurement()
    _ = scopedStore(for: 10)
  }

  Benchmark("NestedStore.Send") { @MainActor benchmark async in
    let store = scopedStore(for: 10)
    benchmark.startMeasurement()
    blackHole(store.send(.incrementButtonTapped))
  }

  Benchmark("NestedStore.RootSend") { @MainActor benchmark async in
    let root = rootStore(for: 10)
    let store = scopedStore(for: 10, from: root)
    benchmark.startMeasurement()
    blackHole(root.send(.incrementButtonTapped))
  }

  Benchmark("NestedStore.NestedSend(1)") { @MainActor benchmark async in
    let root = rootStore(for: 10)
    let store = scopedStore(for: 10, from: root)
    benchmark.startMeasurement()
    blackHole(root.send(.child(.presented(.incrementButtonTapped))))
  }

  Benchmark("NestedStore.Access") { @MainActor benchmark async in
    let store = scopedStore(for: 10)
    benchmark.startMeasurement()
    blackHole(store.state)
  }
}

@Reducer
private struct Feature {
  @ObservableState
  struct State {
    var count = 0
    @Presents var child: Feature.State?
  }
  enum Action {
    indirect case child(PresentationAction<Feature.Action>)
    case incrementButtonTapped
  }
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .child:
        return .none
      case .incrementButtonTapped:
        state.count += 1
        return .none
      }
    }
    .ifLet(\.$child, action: \.child) {
      Feature()
    }
  }
}
