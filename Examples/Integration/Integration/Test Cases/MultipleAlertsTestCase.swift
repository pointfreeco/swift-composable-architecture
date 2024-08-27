import ComposableArchitecture
import SwiftUI

@Reducer
private struct MultipleAlertsTestCase {
  @ObservableState
  struct State: Equatable {
    @Presents var alert: AlertState<Action.Alert>?
  }
  enum Action {
    case alert(PresentationAction<Alert>)
    case showAlertButtonTapped

    @CasePathable
    enum Alert {
      case anotherButtonTapped
    }
  }
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .alert(.presented(.anotherButtonTapped)):
        if let title = state.alert?.title {
          state.alert = AlertState {
            title + TextState("!")
          } actions: {
            ButtonState(action: .anotherButtonTapped) {
              TextState("Another!")
            }
            ButtonState(role: .cancel) {
              TextState("I'm done")
            }
          }
        }
        return .none

      case .alert:
        return .none

      case .showAlertButtonTapped:
        state.alert = AlertState {
          TextState("Hello")
        } actions: {
          ButtonState(action: .anotherButtonTapped) {
            TextState("Another!")
          }
          ButtonState(role: .cancel) {
            TextState("I'm done")
          }
        }
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
    ._printChanges()
  }
}

struct MultipleAlertsTestCaseView: View {
  @Perception.Bindable private var store = Store(initialState: MultipleAlertsTestCase.State()) {
    MultipleAlertsTestCase()
  }

  var body: some View {
    WithPerceptionTracking {
      VStack {
        Button("Show alert") {
          store.send(.showAlertButtonTapped)
        }
      }
      .alert($store.scope(state: \.alert, action: \.alert))
    }
  }
}
