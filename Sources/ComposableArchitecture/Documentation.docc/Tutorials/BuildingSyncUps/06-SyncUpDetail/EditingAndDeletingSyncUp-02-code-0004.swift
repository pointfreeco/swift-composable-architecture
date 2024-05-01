import ComposableArchitecture
import SwiftUI

@Reducer
struct SyncUpDetail {
  @ObservableState
  struct State {
    @Presents var alert: AlertState<Action.Alert>?
    @Presents var editSyncUp: SyncUpForm.State?
    @Shared var syncUp: SyncUp
  }

  enum Action {
    case alert(PresentationAction<Alert>)
    case cancelEditButtonTapped
    case deleteButtonTapped
    case doneEditingButtonTapped
    case editButtonTapped
    case editSyncUp(PresentationAction<SyncUpForm.Action>)
    @CasePathable
    enum Alert {
      case confirmButtonTapped
    }
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .alert:
        return .none
        
      case .cancelEditButtonTapped:
        state.editSyncUp = nil
        return .none

      case .deleteButtonTapped:
        return .none

      case .doneEditingButtonTapped:
        guard let editedSyncUp = state.editSyncUp?.syncUp
        else { return .none }
        state.syncUp = editedSyncUp
        state.editSyncUp = nil
        return .none

      case .editButtonTapped:
        state.editSyncUp = SyncUpForm.State(syncUp: state.syncUp)
        return .none

      case .editSyncUp:
        return .none
      }
    }
    .ifLet(\.$editSyncUp, action: \.editSyncUp) {
      SyncUpForm()
    }
    .ifLet(\.$alert, action: \.alert) {
      
    }
  }
}

struct SyncUpDetailView: View {
  // ...
}
