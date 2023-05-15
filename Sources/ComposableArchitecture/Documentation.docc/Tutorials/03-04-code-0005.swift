struct CounterFeature: ReducerProtocol {
  struct State: Equatable {
    // ...
  }

  enum Action: Equatable {
    // ...
  }

  @Dependency(\.continuousClock) var clock
  @Dependency(\.numberFact) var numberFact

  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
      // ...

    case .factButtonTapped:
      state.fact = nil
      state.isLoading = true
      return .run { [count = state.count] send in
        try await send(.factResponse(self.numberFact.fetch(count)))
      }
    }
  }
}
