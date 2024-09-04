@_spi(Logging) import ComposableArchitecture
import SwiftUI

struct SiblingFeaturesView: View {
  @State var store = Store(initialState: Feature.State()) {
    Feature()
  }

  var body: some View {
    VStack {
      Form {
        Section {
          BasicsView(
            store: self.store.scope(state: \.child1, action: \.child1)
          )
        } header: {
          Text("Child 1")
        }
        Section {
          BasicsView(
            store: self.store.scope(state: \.child2, action: \.child2)
          )
        } header: {
          Text("Child 2")
        }
        Section {
          Button("Reset all") {
            self.store.send(.resetAllButtonTapped)
          }
          Button("Reset self") {
            self.store.send(.resetSelfButtonTapped)
          }
          Button("Swap") {
            self.store.send(.swapButtonTapped)
          }
        }
      }
    }
  }

  @Reducer
  struct Feature {
    struct State: Equatable {
      var child1 = BasicsView.Feature.State()
      var child2 = BasicsView.Feature.State()
    }
    enum Action {
      case child1(BasicsView.Feature.Action)
      case child2(BasicsView.Feature.Action)
      case resetAllButtonTapped
      case resetSelfButtonTapped
      case swapButtonTapped
    }
    var body: some ReducerOf<Self> {
      Scope(state: \.child1, action: \.child1) {
        BasicsView.Feature()
      }
      Scope(state: \.child2, action: \.child2) {
        BasicsView.Feature()
      }
      Reduce { state, action in
        switch action {
        case .child1:
          return .none
        case .child2:
          return .none
        case .resetAllButtonTapped:
          state.child1 = BasicsView.Feature.State()
          state.child2 = BasicsView.Feature.State()
          return .none
        case .resetSelfButtonTapped:
          state = State()
          return .none
        case .swapButtonTapped:
          let copy = state.child1
          state.child1 = state.child2
          state.child2 = copy
          return .none
        }
      }
    }
  }
}
