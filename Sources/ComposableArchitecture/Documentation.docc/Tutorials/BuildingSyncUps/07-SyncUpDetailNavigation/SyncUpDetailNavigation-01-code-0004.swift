import ComposableArchitecture
import SwiftUI

@Reducer
struct App {
  @Reducer
  enum Path {
  }
  @ObservableState
  struct State {
    var path = StackState<SyncUpDetail.State>()
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
