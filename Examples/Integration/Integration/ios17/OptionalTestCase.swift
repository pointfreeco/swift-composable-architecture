import ComposableArchitecture
import SwiftUI

struct OptionalView: View {
  @State var store = Store(initialState: Feature.State()) {
    Feature()
  }

  var body: some View {
    Form {
      Section {
        Button("Toggle") {
          self.store.send(.toggleButtonTapped)
        }
      }
    }
    if let childStore = self.store.scope(state: \.child, action: { .child($0) }) {
      BasicsView(store: childStore)
    }
  }

  struct Feature: Reducer {
    @ObservableState
    struct State {
      @ObservationStateIgnored
      @PresentationState var child: BasicsView.Feature.State?
    }
    @CasePathable
    enum Action {
      case child(PresentationAction<BasicsView.Feature.Action>)
      case toggleButtonTapped
    }
    var body: some ReducerOf<Self> {
      Reduce { state, action in
          .none
      }
      .ifLet(\.$child, action: #casePath(\.child)) {
        BasicsView.Feature()
      }
    }
  }
}
