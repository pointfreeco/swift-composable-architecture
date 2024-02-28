@_spi(Logging) import ComposableArchitecture
import SwiftUI

struct NewOldSiblingsView: View {
  @State var store = Store(initialState: Feature.State()) {
    Feature()
  }

  var body: some View {
    let _ = Logger.shared.log("\(Self.self).body")
    Form {
      Section {
        BasicsView(
          store: self.store.scope(state: \.child1, action: \.child1)
        )
      } header: {
        Text("iOS 16")
      }

      Section {
        ObservableBasicsView(
          store: self.store.scope(state: \.child2, action: \.child2)
        )
      } header: {
        Text("iOS 17")
      }

      Section {
        Button("Reset all") {
          self.store.send(.resetAllButtonTapped)
        }
        Button("Reset self") {
          self.store.send(.resetSelfButtonTapped)
        }
      }
    }
  }

  @Reducer
  struct Feature {
    struct State: Equatable {
      var child1 = BasicsView.Feature.State()
      var child2 = ObservableBasicsView.Feature.State()
    }
    enum Action {
      case child1(BasicsView.Feature.Action)
      case child2(ObservableBasicsView.Feature.Action)
      case resetAllButtonTapped
      case resetSelfButtonTapped
    }
    var body: some ReducerOf<Self> {
      Scope(state: \.child1, action: \.child1) {
        BasicsView.Feature()
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
          state.child1 = BasicsView.Feature.State()
          state.child2 = ObservableBasicsView.Feature.State()
          return .none
        case .resetSelfButtonTapped:
          state = State()
          return .none
        }
      }
    }
  }
}

#Preview {
  Logger.shared.isEnabled = true
  return NewOldSiblingsView()
}
