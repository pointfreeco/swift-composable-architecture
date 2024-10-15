import Combine
import ComposableArchitecture
import XCTest

final class CompatibilityTests: BaseTCATestCase {
  // Actions can be re-entrantly sent into the store if an action is sent that holds an object
  // which sends an action on deinit. In order to prevent a simultaneous access exception for this
  // case we need to use `withExtendedLifetime` on the buffered actions when clearing them out.
  @MainActor
  func testCaseStudy_ActionReentranceFromClearedBufferCausingDeinitAction() {
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
        case .actionSender:
          return "actionSender"
        case .stop:
          return "stop"
        }
      }
    }
    let passThroughSubject = PassthroughSubject<Action, Never>()

    var handledActions: [String] = []

    let reducer = Reduce<State, Action> { state, action in
      handledActions.append(action.description)

      switch action {
      case .start:
        return .publisher { passThroughSubject }.cancellable(id: cancelID)

      case .kickOffAction:
        return .send(.actionSender(OnDeinit { passThroughSubject.send(.stop) }))

      case .actionSender:
        return .none

      case .stop:
        return .cancel(id: cancelID)
      }
    }

    let store = Store(initialState: .init()) {
      reducer
    }

    let viewStore = ViewStore(store, observe: { $0 })

    viewStore.send(.start)
    viewStore.send(.kickOffAction)

    XCTAssertEqual(
      handledActions,
      [
        "start",
        "kickOffAction",
        "actionSender",
        "stop",
      ]
    )
  }

  // Actions can be re-entrantly sent into the store while observing changes to the store's state.
  // In such cases we need to take special care that those re-entrant actions are handled _after_
  // the original action.
  //
  // In particular, this means that in the implementation of `Store.send` we need to flip
  // `isSending` to false _after_ the store's state mutation is made so that re-entrant actions
  // are buffered rather than immediately handled.
  @MainActor
  func testCaseStudy_ActionReentranceFromStateObservation() {
    var cancellables: Set<AnyCancellable> = []
    defer { _ = cancellables }

    let store = Store<Int, Int>(initialState: 0) {
      Reduce { state, action in
        state = action
        return .none
      }
    }

    let viewStore = ViewStore(store, observe: { $0 })

    viewStore.publisher
      .sink { value in
        if value == 1 {
          viewStore.send(0)
        }
      }
      .store(in: &cancellables)

    var stateChanges: [Int] = []
    viewStore.publisher
      .sink {
        stateChanges.append($0)
      }
      .store(in: &cancellables)

    XCTAssertEqual(stateChanges, [0])
    viewStore.send(1)
    XCTAssertEqual(stateChanges, [0, 1, 0])
  }
}

private final class OnDeinit: Equatable {
  private let onDeinit: () -> Void
  init(onDeinit: @escaping () -> Void) {
    self.onDeinit = onDeinit
  }
  deinit { self.onDeinit() }
  static func == (lhs: OnDeinit, rhs: OnDeinit) -> Bool { true }
}
