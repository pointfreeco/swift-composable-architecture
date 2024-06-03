import ComposableArchitecture
import SwiftUI

@Reducer
struct AppFeature {
  @Reducer
  enum Path {
    case detail(SyncUpDetail)
  }
  @ObservableState
  struct State: Equatable {
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
