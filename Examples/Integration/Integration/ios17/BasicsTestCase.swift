import ComposableArchitecture
import SwiftUI

struct BasicsView: View {
  @State var store = Store(initialState: Feature.State()) {
    Feature()
  }

  var body: some View {
    let _ = Log.shared.log("\(Self.self).body")
    Form {
      Text(self.store.count.description)
      Button("Decrement") { self.store.send(.decrementButtonTapped) }
      Button("Increment") { self.store.send(.incrementButtonTapped) }
      Button("Dismiss") { self.store.send(.dismissButtonTapped) }
    }
  }

  struct Feature: Reducer {
    @ObservableState
    struct State {
      var count = 0
      var isDismissable: Bool
      init(count: Int = 0) {
        self.count = count
        @Dependency(\.isPresented) var isPresented
        self.isDismissable = isPresented
      }
    }
    enum Action {
      case decrementButtonTapped
      case dismissButtonTapped
      case incrementButtonTapped
    }
    @Dependency(\.dismiss) var dismiss
    var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .decrementButtonTapped:
          state.count -= 1
          return .none
        case .dismissButtonTapped:
          return .run { _ in await self.dismiss() }
        case .incrementButtonTapped:
          state.count += 1
          return .none
        }
      }
    }
  }
}
