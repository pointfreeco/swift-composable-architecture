struct CounterFeature: ReducerProtocol {
  struct State: Equatable {
    // ...
  }

  enum Action: Equatable {
    // ...
  }

  @Dependency(\.continuousClock) var clock

  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    // ...

    case .toggleTimerButtonTapped:
      state.isTimerRunning.toggle()
      if state.isTimerRunning {
        return .run { send in
          for await _ in self.clock.timer(interval: .seconds(1)) {
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
