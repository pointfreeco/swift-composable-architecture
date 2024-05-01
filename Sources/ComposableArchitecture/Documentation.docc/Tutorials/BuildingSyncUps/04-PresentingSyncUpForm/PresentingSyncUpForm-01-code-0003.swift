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
    case onDelete(IndexSet)
    case syncUpTapped(id: SyncUp.ID)
  }
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .addSyncUpButtonTapped:
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
  }
}
