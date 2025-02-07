import ComposableArchitecture
import SwiftUI

@Reducer
struct SyncUpDetail {
  @Reducer
  enum Destination {
    case alert(AlertState<Alert>)
    case edit(SyncUpForm)
    @CasePathable
    enum Alert {
      case confirmButtonTapped
    }
  }

  @ObservableState
  struct State: Equatable {
    @Presents var destination: Destination.State?
    @Shared var syncUp: SyncUp
  }

  enum Action {
    case cancelEditButtonTapped
    case deleteButtonTapped
    case destination(PresentationAction<Destination.Action>)
    case doneEditingButtonTapped
    case editButtonTapped
  }

  @Dependency(\.dismiss) var dismiss

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      // case .alert(.presented(.confirmButtonTapped)):
      case .destination(.presented(.alert(.confirmButtonTapped))):
        @Shared(.syncUps) var syncUps
        $syncUps.withLock { _ = $0.remove(id: state.syncUp.id) }
        return .run { _ in await dismiss() }

      case .destination:
        return .none

      case .cancelEditButtonTapped:
        state.destination = nil
        return .none

      case .deleteButtonTapped:
        state.destination = .alert(.deleteSyncUp)
        return .none

      case .doneEditingButtonTapped:
        guard let editedSyncUp = state.destination?.edit?.syncUp
        else { return .none }
        state.$syncUp.withLock { $0 = editedSyncUp }
        state.destination = nil
        return .none

      case .editButtonTapped:
        // state.editSyncUp = SyncUpForm.State(syncUp: state.syncUp)
        state.destination = .edit(SyncUpForm.State(syncUp: state.syncUp))
        return .none
      }
    }
    .ifLet(\.$destination, action: \.destination)
  }
}
extension SyncUpDetail.Destination.State: Equatable {}

extension AlertState where Action == SyncUpDetail.Destination.Alert {
  static let deleteSyncUp = Self {
    TextState("Delete?")
  } actions: {
    ButtonState(role: .destructive, action: .confirmButtonTapped) {
      TextState("Yes")
    }
    ButtonState(role: .cancel) {
      TextState("Nevermind")
    }
  } message: {
    TextState("Are you sure you want to delete this meeting?")
  }
}

struct SyncUpDetailView: View {
  // ...
}
