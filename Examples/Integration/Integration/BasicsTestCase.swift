@_spi(Logging) import ComposableArchitecture
import SwiftUI

struct BasicsView: View {
  @State var store = Store(initialState: Feature.State()) {
    Feature()
  }

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      let _ = Logger.shared.log("\(Self.self).body")
      Text(viewStore.count.description)
      Button("Decrement") { self.store.send(.decrementButtonTapped) }
      Button("Increment") { self.store.send(.incrementButtonTapped) }
      Button("Dismiss") { self.store.send(.dismissButtonTapped) }
    }
  }

  struct Feature: Reducer {
    struct State: Equatable, Identifiable {
      let id = UUID()
      var count = 0
      init(count: Int = 0) {
        self.count = count
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
