import ComposableArchitecture
import SwiftUI

@Reducer
struct SyncUpForm {
  @ObservableState
  struct State: Equatable {
    var syncUp: SyncUp
  }

  enum Action: BindableAction {
    case binding(BindingAction<State>)
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      }
    }
  }
}
