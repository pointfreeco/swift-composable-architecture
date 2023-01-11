import Combine
import ComposableArchitecture
import XCTest

@MainActor
@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
final class PresentationAlertTests: XCTestCase {
  func testDestinations() async {
    let store = TestStore(
      initialState: FeatureWithDestinations.State(),
      reducer: FeatureWithDestinations()
    )
    await store.send(.buttonTapped) {
      $0.destination = .alert(.alert)
    }
    await store.send(.destination(.presented(.alert(.confirm)))) {
      $0.destination = nil
      $0.count = 1
    }

    await store.send(.buttonTapped) {
      $0.destination = .alert(.alert)
    }
    await store.send(.destination(.presented(.alert(.deny)))) {
      $0.destination = nil
      $0.count = 0
    }

    await store.send(.buttonTapped) {
      $0.destination = .alert(.alert)
    }
    await store.send(.destination(.dismiss)) {
      $0.destination = nil
    }
  }

  func testAlerts() async {
    let store = TestStore(
      initialState: FeatureWithAlert.State(),
      reducer: FeatureWithAlert()
    )
    await store.send(.buttonTapped) {
      $0.alert = .alert
    }
    await store.send(.alert(.presented(.confirm))) {
      $0.alert = nil
      $0.count = 1
    }

    await store.send(.buttonTapped) {
      $0.alert = .alert
    }
    await store.send(.alert(.presented(.deny))) {
      $0.alert = nil
      $0.count = 0
    }

    await store.send(.buttonTapped) {
      $0.alert = .alert
    }
    await store.send(.alert(.dismiss)) {
      $0.alert = nil
    }
  }
}

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
private struct FeatureWithDestinations: ReducerProtocol {
  struct State: Equatable {
    var count = 0
    @PresentationStateOf<Destinations> var destination
  }
  enum Action: Equatable {
    case buttonTapped
    case destination(PresentationActionOf<Destinations>)
  }

  struct Destinations: ReducerProtocol {
    enum State: Equatable {
      case alert(AlertState<AlertAction>)
    }
    enum Action: Equatable {
      case alert(AlertAction)
    }
    var body: some ReducerProtocolOf<Self> {
      EmptyReducer()
    }
  }

  var body: some ReducerProtocolOf<Self> {
    Reduce { state, action in
      switch action {
      case .buttonTapped:
        state.destination = .alert(.alert)
        return .none

      case .destination(.presented(.alert(.confirm))):
        state.count += 1
        return .none

      case .destination(.presented(.alert(.deny))):
        state.count -= 1
        return .none

      case .destination:
        return .none
      }
    }
    .presentationDestination(\.$destination, action: /Action.destination) {
      Destinations()
    }
  }
}

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
private struct FeatureWithAlert: ReducerProtocol {
  struct State: Equatable {
    var count = 0
    @PresentationState<AlertState<AlertAction>> var alert
  }
  enum Action: Equatable {
    case buttonTapped
    case alert(PresentationAction<AlertState<AlertAction>, AlertAction>)
  }

  var body: some ReducerProtocolOf<Self> {
    Reduce { state, action in
      switch action {
      case .buttonTapped:
        state.alert = .alert
        return .none

      case .alert(.presented(.confirm)):
        state.count += 1
        return .none

      case .alert(.presented(.deny)):
        state.count -= 1
        return .none

      case .alert:
        return .none
      }
    }
    .presentationDestination(\.$alert, action: /Action.alert) {
      EmptyReducer()
    }
  }
}

enum AlertAction {
  case confirm
  case deny
}

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
extension AlertState where Action == AlertAction {
  fileprivate static let alert = AlertState {
    TextState("What do you want to do?")
  } actions: {
    ButtonState(role: .cancel) {
      TextState("Cancel")
    }
    ButtonState(action: .confirm) {
      TextState("Confirm")
    }
    ButtonState(role: .destructive, action: .deny) {
      TextState("Deny")
    }
  }

}
