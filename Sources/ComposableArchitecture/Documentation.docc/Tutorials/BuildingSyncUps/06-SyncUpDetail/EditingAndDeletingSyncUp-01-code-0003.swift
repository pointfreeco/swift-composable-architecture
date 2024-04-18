import ComposableArchitecture
import SwiftUI

@Reducer
struct SyncUpDetail {
  @ObservableState
  struct State {
    @Presents var editSyncUp: SyncUpForm.State?
    @Shared var syncUp: SyncUp
  }

  enum Action {
    case deleteButtonTapped
    case editButtonTapped
    case editSyncUp(PresentationAction<SyncUpForm.Action>)
    case startMeetingButtonTapped
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .deleteButtonTapped:
        return .none

      case .editButtonTapped:
        return .none

      case .editSyncUp:
        return .none

      case .startMeetingButtonTapped:
        return .none
      }
    }
    .ifLet(\.$editSyncUp, action: \.editSyncUp) {
      SyncUpForm()
    }
  }
}

struct SyncUpDetailView: View {
  // ...
}
