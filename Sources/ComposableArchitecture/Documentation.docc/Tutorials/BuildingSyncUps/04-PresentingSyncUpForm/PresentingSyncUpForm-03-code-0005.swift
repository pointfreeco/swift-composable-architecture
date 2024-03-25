import ComposableArchitecture
import SwiftUI

@Reducer
struct SyncUpsList {
  @ObservableState
  struct State: Equatable {
    @Presents var addSyncUp: SyncUpForm.State?
    var syncUps: IdentifiedArrayOf<SyncUp> = []
  }
  enum Action {
    case addSyncUpButtonTapped
    case addSyncUp(PresentationAction<SyncUpForm.Action>)
    case confirmAddButtonTapped
    case discardButtonTapped
    case onDelete(IndexSet)
    case syncUpTapped(id: SyncUp.ID)
  }
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .addSyncUpButtonTapped:
        state.addSyncUp = SyncUpForm.State(syncUp: SyncUp(id: SyncUp.ID()))
        return .none

      case .addSyncUp:
        return .none

      case .confirmAddButtonTapped:
        guard let newSyncUp = state.addSyncUp?.syncUp
        else { return .none }
        state.addSyncUp = nil
        state.syncUps.append(newSyncUp)
        return .none

      case .discardButtonTapped:
        state.addSyncUp = nil
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
