import ComposableArchitecture
import SwiftUI

@Reducer
struct App {
  @ObservableState
  struct State: Equatable {
    var syncUpsList = SyncUpsList.State()
  }
  enum Action {
    case syncUpsList(SyncUpsList.Action)
  }
  var body: some ReducerOf<Self> {
    Scope(state: \.syncUpsList, action: \.syncUpsList) {
      SyncUpsList()
    }
    Reduce { state, action in
      switch action {
      case .syncUpsList:
        return .none
      }
    }
  }
}
