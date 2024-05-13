import ComposableArchitecture
import SwiftUI

@Reducer
struct App {
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
