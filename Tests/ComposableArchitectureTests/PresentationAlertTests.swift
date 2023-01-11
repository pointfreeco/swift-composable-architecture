import Combine
import ComposableArchitecture
import XCTest

@MainActor
@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
final class PresentationAlertTests: XCTestCase {
  func testBasics() async {
    let store = TestStore(
      initialState: Feature.State(),
      reducer: Feature()
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
}

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
private struct Feature: ReducerProtocol {
  struct State: Equatable {
    var count = 0
    @PresentationStateOf<Destinations> var destination
  }
  enum Action: Equatable {
    case buttonTapped
    case destination(PresentationActionOf<Destinations>)
  }
  enum AlertAction {
    case confirm
    case deny
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
extension AlertState where Action == Feature.AlertAction {
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
