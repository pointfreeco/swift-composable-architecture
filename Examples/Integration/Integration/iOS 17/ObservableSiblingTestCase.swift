@_spi(Logging) import ComposableArchitecture
import SwiftUI

struct ObservableSiblingFeaturesView: View {
  @State var store = Store(initialState: Feature.State()) {
    Feature()
  }

  var body: some View {
    ObservedView {
      let _ = Logger.shared.log("\(Self.self).body")
      VStack {
        Form {
          ObservableBasicsView(
            store: self.store.scope(state: \.child1, action: \.child1)
          )
        }
        Form {
          ObservableBasicsView(
            store: self.store.scope(state: \.child2, action: \.child2)
          )
        }
        Spacer()
        Form {
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
    @ObservableState
    struct State: Equatable {
      var child1 = ObservableBasicsView.Feature.State()
      var child2 = ObservableBasicsView.Feature.State()
    }
    enum Action {
      case child1(ObservableBasicsView.Feature.Action)
      case child2(ObservableBasicsView.Feature.Action)
      case resetAllButtonTapped
      case resetSelfButtonTapped
      case swapButtonTapped
    }
    var body: some ReducerOf<Self> {
      Scope(state: \.child1, action: \.child1) {
        ObservableBasicsView.Feature()
      }
      Scope(state: \.child2, action: \.child2) {
        ObservableBasicsView.Feature()
      }
      Reduce { state, action in
        switch action {
        case .child1:
          return .none
        case .child2:
          return .none
        case .resetAllButtonTapped:
          state.child1 = ObservableBasicsView.Feature.State()
          state.child2 = ObservableBasicsView.Feature.State()
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
