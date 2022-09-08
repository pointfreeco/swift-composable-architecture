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

      var description: String {
        switch self {
        case .start:
          return "start"
        case .kickOffAction:
          return "kickOffAction"
        case .actionSender(_):
          return "actionSender"
        case .stop:
          return "stop"
        }
      }
    }
    let passThroughSubject = PassthroughSubject<Action, Never>()

    var handledActions: [String] = []

    let reducer = Reducer<State, Action, Void> { state, action, env in
      handledActions.append(action.description)

      switch action {
      case .start:
        return passThroughSubject
          .eraseToEffect()
          .cancellable(id: cancelID)

      case .kickOffAction:
        return Effect(value: .actionSender(OnDeinit { passThroughSubject.send(.stop) }))

      case .actionSender:
        return .none

      case .stop:
        return .cancel(id: cancelID)
      }
    }

    let store = Store(
      initialState: .init(),
      reducer: reducer,
      environment: ()
    )

    let viewStore = ViewStore(store)

    viewStore.send(.start)
    viewStore.send(.kickOffAction)

    XCTAssertNoDifference(
      handledActions,
      [
        "start",
        "kickOffAction",
        "actionSender",
        "stop",
      ]
    )
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
