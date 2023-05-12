import ComposableArchitecture

struct CounterFeature: ReducerProtocol {
  struct State: Equatable {
    // ...
    var isTimerRunning = false
  }

  enum Action {
    // ...
    case timerTick
    case toggleTimerButtonTapped
  }

  enum CancelID { case timer }

  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    // ...

    case .timerTick:
      state.count += 1
      state.fact = nil
      return .none
      
    case .toggleTimerButtonTapped:
      state.isTimerRunning.toggle()
      if state.isTimerRunning {
        return .run { send in
          while true {
            try await Task.sleep(for: .seconds(1))
            await send(.timerTick)
          }
        }
        .cancellable(id: CancelID.timer)
      } else {
        return .cancel(id: CancelID.timer)
      }
    }
  }
}
