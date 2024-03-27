import ComposableArchitecture
import SwiftUI

@Reducer
struct App {
  // ...
}

extension App {
  @Reducer
  struct Path {
    @ObservableState
    enum State {
      case detail(SyncUpDetail.State)
    }
    enum Action {
      case detail(SyncUpDetail.Action)
    }
    var body: some ReducerOf<Self> {
      Scope(state: \.detail, action: \.detail) {
        SyncUpDetail()
      }
    }
  }
}
