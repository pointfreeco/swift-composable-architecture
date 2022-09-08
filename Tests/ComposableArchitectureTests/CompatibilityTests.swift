import Combine
import CombineSchedulers
import ComposableArchitecture
import XCTest

@MainActor
final class CompatibilityTests: XCTestCase {
  func testBrowserCaseStudy_ReentrantEffect() {
    struct State: Equatable {}
    enum Action: Equatable {
      case start
      case kickOffAction
      case actionSender(OnDeinit)
      case stop
    }
    struct Environment {
      var longRunningEffect: () -> Effect<Action, Never>
    }
    let passThroughSubject = PassthroughSubject<Action, Never>()

    let reducer = Reducer<State, Action, Environment> { state, action, env in
      switch action {
      case .start:
        return env.longRunningEffect().cancellable(id: 1)
      case .kickOffAction:
        return .init(value: .actionSender(.init(onDeinit: { passThroughSubject.send(.stop)})))
      case .actionSender:
        return .none
      case .stop:
        return .cancel(id: 1)
      }
    }

    let store = TestStore(
      initialState: .init(),
      reducer: reducer,
      environment: .init(longRunningEffect: { passThroughSubject.eraseToEffect() })
    )

    store.send(.start)
    store.send(.kickOffAction)
    store.receive(.actionSender(OnDeinit { }))
    store.receive(.stop)
  }
}

private final class OnDeinit: Equatable {
  private let onDeinit: () -> ()
  init(onDeinit: @escaping () -> ()) {
    self.onDeinit = onDeinit
  }
  deinit { self.onDeinit() }
  static func == (lhs: OnDeinit, rhs: OnDeinit) -> Bool { true }
}
