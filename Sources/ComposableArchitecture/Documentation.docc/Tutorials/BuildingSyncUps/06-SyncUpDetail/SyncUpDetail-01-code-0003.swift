import ComposableArchitecture
import SwiftUI

@Reducer
struct SyncUpDetail {
  @ObservableState
  struct State {
    @Shared var syncUp: SyncUp
  }

  enum Action {
    case deleteButtonTapped
    case editButtonTapped
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      }
    }
  }
}
