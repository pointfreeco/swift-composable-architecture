import Benchmark
import Combine
@_spi(Internals) import ComposableArchitecture
import Foundation

let storeSuite = BenchmarkSuite(name: "Store") {
  var store: StoreOf<Feature>!
  let levels = 5

  for level in 1...levels {
    $0.benchmark("Nested send tap: \(level)") {
      _ = store.send(tap(level: level))
    } setUp: {
      store = Store(initialState: state(level: level)) {
        Feature()
      }
    } tearDown: {
      precondition(count(of: store.state.value, level: level) == 1)
      _cancellationCancellables.removeAll()
    }
  }
  for level in 1...levels {
    $0.benchmark("Nested send none: \(level)") {
      _ = store.send(none(level: level))
    } setUp: {
      store = Store(initialState: state(level: level)) {
        Feature()
      }
    } tearDown: {
      precondition(count(of: store.state.value, level: level) == 0)
      _cancellationCancellables.removeAll()
    }
  }
}

private struct Feature: ReducerProtocol {
  struct State {
    @PresentationState var child: State?
    var count = 0
  }
  enum Action {
    indirect case child(PresentationAction<Action>)
    case tap
    case none
  }
  var body: some ReducerProtocol<State, Action> {
    Reduce<State, Action> { state, action in
      switch action {
      case .child:
        return .none
      case .tap:
        state.count = 1
        return Empty(completeImmediately: true)
          .eraseToEffect()
          .cancellable(id: UUID())
      case .none:
        return .none
      }
    }
    .ifLet(\.$child, action: /Action.child) {
      Feature()
    }
  }
}

private func state(level: Int) -> Feature.State {
  Feature.State(
    child: level == 0
      ? nil
      : state(level: level - 1)
  )
}
private func tap(level: Int) -> Feature.Action {
  level == 0
    ? .tap
    : Feature.Action.child(.presented(tap(level: level - 1)))
}
private func none(level: Int) -> Feature.Action {
  level == 0
    ? .none
    : Feature.Action.child(.presented(none(level: level - 1)))
}
private func count(of state: Feature.State?, level: Int) -> Int? {
  level == 0
    ? state?.count
    : count(of: state?.child, level: level - 1)
}
