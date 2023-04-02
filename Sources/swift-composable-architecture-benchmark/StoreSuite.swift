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
      store = Store(
        initialState: state(level: level),
        reducer: Feature()
      )
    } tearDown: {
      precondition(count(of: store.state.value, level: level) == 1)
      precondition(_cancellationCancellables.count == 0)
    }
  }
  for level in 1...levels {
    $0.benchmark("Nested send none: \(level)") {
      _ = store.send(none(level: level))
    } setUp: {
      store = Store(
        initialState: state(level: level),
        reducer: Feature()
      )
    } tearDown: {
      precondition(count(of: store.state.value, level: level) == 0)
      precondition(_cancellationCancellables.count == 0)
    }
  }
}

private struct Feature: ReducerProtocol {
  struct State {
    @Box var child: State?
    var count = 0
  }
  enum Action {
    indirect case child(Action)
    case tap
    case none
  }
  var body: some ReducerProtocolOf<Self> {
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
    .ifLet(\.child, action: /Action.child) {
      Feature()
    }
  }
}

@propertyWrapper
private struct Box<Value> {
  private var value: [Value]
  var wrappedValue: Value? {
    get { self.value.first }
    set { self.value = newValue.map { [$0] } ?? [] }
  }
  init(wrappedValue: Value?) {
    self.value = wrappedValue.map { [$0] } ?? []
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
    : Feature.Action.child(tap(level: level - 1))
}
private func none(level: Int) -> Feature.Action {
  level == 0
    ? .none
    : Feature.Action.child(none(level: level - 1))
}
private func count(of state: Feature.State?, level: Int) -> Int? {
  level == 0
    ? state?.count
    : count(of: state?.child, level: level - 1)
}
