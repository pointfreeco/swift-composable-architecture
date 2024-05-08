import ComposableArchitecture
import SwiftUI

@Reducer
struct SyncUpsList {
  @ObservableState
  struct State: Equatable {
    var syncUps: IdentifiedArrayOf<SyncUp> = []
  }
  enum Action {
    case addSyncUpButtonTapped
    case onDelete(IndexSet)
    case syncUpTapped(id: SyncUp.ID)
  }
}
