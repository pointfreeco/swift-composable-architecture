import ComposableArchitecture
import SwiftUI

@Reducer
struct SyncUpsList {
  @ObservableState
  struct State {
    @Presents var addSyncUp: SyncUpForm.State?
    var syncUps: IdentifiedArrayOf<SyncUps> = []
  }
  enum Action {
    case addButtonTapped
    case addSyncUp(PresentationAction<SyncUpForm.Action>)
    case onDelete(IndexSet)
    case syncUpTapped(id: SyncUp.ID)
  }
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .addButtonTapped:
        return .none

      case .addSyncUp:
        return .none

      case let .onDelete(indexSet):
        state.syncUps.remove(atOffsets: indexSet)
        return .none

      case .syncUpTapped:
        return .none
      }
    }
    .ifLet(\.$addSyncUp, action: \.addSyncUp) {
      SyncUpForm()
    }
  }
}
