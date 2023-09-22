import ComposableArchitecture
import SwiftUI

struct BasicsView: View {
  @State var store = Store(initialState: Feature.State()) {
    Feature()
  }

  var body: some View {
    Form {
      Text(self.store.count.description)
      Button("Decrement") { self.store.send(.decrementButtonTapped) }
      Button("Increment") { self.store.send(.incrementButtonTapped) }
    }
  }

  struct Feature: Reducer {
    @ObservableState
    struct State {
      var count = 0
    }
    enum Action {
      case decrementButtonTapped, incrementButtonTapped
    }
    var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .decrementButtonTapped:
          state.count -= 1
          return .none
        case .incrementButtonTapped:
          state.count += 1
          return .none
        }
      }
    }
  }
}
