@_spi(Logging) import ComposableArchitecture
import SwiftUI

struct ObservableSiblingFeaturesView: View {
  @Perception.Bindable var store = Store(initialState: Feature.State()) {
    Feature()
  }

  var body: some View {
    WithPerceptionTracking {
      let _ = Logger.shared.log("\(Self.self).body")
      VStack {
        Form {
          Section {
            ObservableBasicsView(
              store: self.store.scope(state: \.child1, action: \.child1)
            )
          } header: {
            Text("Child 1")
          }
          Section {
            ObservableBasicsView(
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
        // NB: Conditional child views of `Form` that use `@State` are stale when they reappear.
        //     This `id` forces a refresh.
        //
        // Feedback filed: https://gist.github.com/stephencelis/fd078ca2d260c316b70dfc1e0f29883f
        .id(UUID())
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
