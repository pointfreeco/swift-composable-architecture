import Benchmark
import ComposableArchitecture

private func initialState(for nesting: Int) -> Feature.State {
  (1..<nesting).reduce(into: Feature.State()) { state, _ in state = Feature.State(child: state) }
}

@MainActor
private func rootStore(for nesting: Int) -> StoreOf<Feature> {
  Store(initialState: initialState(for: nesting)) { Feature() }
}

@MainActor
private func scopedStore(for nesting: Int) -> StoreOf<Feature> {
  (1..<nesting).reduce(into: rootStore(for: nesting)) { store, _ in
    store = store.scope(state: \.child, action: \.child.presented)!
  }
}

@MainActor
let benchmarks = {
  Benchmark("Scope") { benchmark in
    benchmark.startMeasurement()
    await MainActor.run {
      _ = scopedStore(for: 10)
    }
  }

  Benchmark("Scope and send") { benchmark in
    benchmark.startMeasurement()
    await MainActor.run {
      let store = scopedStore(for: 10)
      store.send(.incrementButtonTapped)
    }
  }

  Benchmark("Scope and send and access") { benchmark in
    benchmark.startMeasurement()
    await MainActor.run {
      let store = scopedStore(for: 10)
      store.send(.incrementButtonTapped)
      blackHole(store.state)
    }
  }

  let store = scopedStore(for: 10)

  Benchmark("Send") { benchmark in
    benchmark.startMeasurement()
    await MainActor.run {
      blackHole(store.send(.incrementButtonTapped))
    }
  }

  Benchmark("Send and receive") { benchmark in
    benchmark.startMeasurement()
    await MainActor.run {
      store.send(.incrementButtonTapped)
      blackHole(store.state)
    }
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
