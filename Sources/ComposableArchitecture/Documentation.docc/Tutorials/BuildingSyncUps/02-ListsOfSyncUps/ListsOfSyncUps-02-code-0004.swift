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
    case syncUpTapped(id: SyncUp.ID)
  }
}
