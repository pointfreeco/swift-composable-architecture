import Combine
import CombineSchedulers
import ComposableArchitecture
import XCTest

@MainActor
final class CompatibilityTests: XCTestCase {
  func testBrowserCaseStudy_ReentrantEffect() {
    let cancelID = UUID()

    struct State: Equatable {}
    enum Action: Equatable {
      case start
      case kickOffAction
      case actionSender(OnDeinit)
      case stop
    }
    let passThroughSubject = PassthroughSubject<Action, Never>()

    let reducer = Reducer<State, Action, Void> { state, action, env in
      switch action {
      case .start:
        return passThroughSubject
          .eraseToEffect()
          .cancellable(id: cancelID)

      case .kickOffAction:
        return Effect(value: .actionSender(.init(onDeinit: { passThroughSubject.send(.stop)})))

      case .actionSender:
        return .none

      case .stop:
        return .cancel(id: cancelID)
      }
    }

    let store = TestStore(
      initialState: .init(),
      reducer: reducer,
      environment: ()
    )

    store.send(.start)
    store.send(.kickOffAction)
    store.receive(.actionSender(OnDeinit {}))
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
