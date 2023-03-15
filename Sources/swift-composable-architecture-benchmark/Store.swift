import Benchmark
import Combine
@_spi(Internals) import ComposableArchitecture
import Foundation

let storeSuite = BenchmarkSuite(name: "Store") {
  let store = Store(
    initialState: Feature.State(
      child: Feature.State(
        child: Feature.State(
          child: Feature.State(
            child: Feature.State(
              child: Feature.State(
                child: nil
              )
            )
          )
        )
      )
    ),
    reducer: Feature()
  )

  $0.benchmark("Deeply nested send") {
    _ = store.send(.child(.child(.child(.child(.child(.tap))))))
    precondition(store.state.value.child?.child?.child?.child?.child?.count == 1)
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
          .cancellable(id: 1)
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
