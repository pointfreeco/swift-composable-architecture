import ComposableArchitecture
import SwiftUI

@Reducer
struct AppReducer {
  @ObservableState
  struct State: Equatable {
  }
  enum Action {
  }
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      }
    }
  }
}
