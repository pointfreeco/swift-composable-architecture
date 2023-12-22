import ComposableArchitecture
import SwiftUI

@Reducer
struct SyncUpsList {
  @ObservableState
  struct State {
    var syncUps: IdentifiedArrayOf<SyncUps> = []
  }
  enum Action {
    case addButtonTapped
    case onDelete(IndexSet)
  }
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .addButtonTapped:
        return .none

      case let .onDelete(indexSet):
        state.syncUps.remove(atOffsets: indexSet)
        return .none
      }
    }
  }
}
