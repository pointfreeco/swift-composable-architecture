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
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .deleteButtonTapped:
        return .none

      case .editButtonTapped:
        return .none
      }
    }
  }
}

struct SyncUpDetailView: View {
  // ...
}
