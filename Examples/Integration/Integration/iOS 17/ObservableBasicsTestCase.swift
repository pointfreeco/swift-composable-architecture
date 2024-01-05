@_spi(Logging) import ComposableArchitecture
import SwiftUI

struct ObservableBasicsView: View {
  var showExtraButtons = false
  @Perception.Bindable var store = Store(initialState: Feature.State()) {
    Feature()
  }

  var body: some View {
    WithPerceptionTracking {
      let _ = Logger.shared.log("\(Self.self).body")
      Text(self.store.count.description)
      Button("Decrement") { self.store.send(.decrementButtonTapped) }
      Button("Increment") { self.store.send(.incrementButtonTapped) }
      Button("Dismiss") { self.store.send(.dismissButtonTapped) }
      if self.showExtraButtons {
        Button("Copy, increment, discard") { self.store.send(.copyIncrementDiscard) }
        Button("Copy, increment, set") { self.store.send(.copyIncrementSet) }
        Button("Reset") { self.store.send(.resetButtonTapped) }
      }
    }
  }

  @Reducer
  struct Feature {
    @ObservableState
    struct State: Equatable, Identifiable {
      let id = UUID()
      var count = 0
    }
    enum Action {
      case copyIncrementDiscard
      case copyIncrementSet
      case decrementButtonTapped
      case dismissButtonTapped
      case incrementButtonTapped
      case resetButtonTapped
    }
    @Dependency(\.dismiss) var dismiss
    var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .copyIncrementDiscard:
          var copy = state
          copy.count += 1
          return .none
        case .copyIncrementSet:
          var copy = state
          copy.count += 1
          state = copy
          return .none
        case .decrementButtonTapped:
          state.count -= 1
          return .none
        case .dismissButtonTapped:
          return .run { _ in await self.dismiss() }
        case .incrementButtonTapped:
          state.count += 1
          return .none
        case .resetButtonTapped:
          state = State()
          return .none
        }
      }
    }
  }
}
