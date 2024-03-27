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
  }
}
