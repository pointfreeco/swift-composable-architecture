import ComposableArchitecture
import SwiftUI

@Reducer
struct App {
  @Reducer
  enum Path {
    case detail(SyncUpDetail)
  }
  @ObservableState
  struct State {
    var path = StackState<Path.State>()
    var syncUpsList = SyncUpsList.State()
  }
  enum Action {
    case path(StackActionOf<Path>)
    case syncUpsList(SyncUpsList.Action)
  }
  var body: some ReducerOf<Self> {
    Scope(state: \.syncUpsList, action: \.syncUpsList) {
      SyncUpsList()
    }
    Reduce { state, action in
      switch action {
      case .path:
        return .none
      case .syncUpsList:
        return .none
      }
    }
  }
}
