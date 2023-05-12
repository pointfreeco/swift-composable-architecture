import ComposableArchitecture

struct CounterFeature: ReducerProtocol {
  struct State: Equatable {
    // ...
    var isTimerRunning = false
  }

  enum Action {
    // ...
    case toggleTimerButtonTapped
  }

  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    // ...
      
    case .toggleTimerButtonTapped:
      state.isTimerRunning.toggle()
      return .run { send in
        
      }
    }
  }
}
