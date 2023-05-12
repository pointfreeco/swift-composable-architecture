import ComposableArchitecture

struct CounterFeature: ReducerProtocol {
  struct State: Equatable {
    var count = 0
    var fact: String?
    var isLoading = false
  }

  enum Action {
    case decrementButtonTapped
    case factButtonTapped
    case incrementButtonTapped
  }

  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    case .decrementButtonTapped:
      state.count -= 1
      return .none

    case .factButtonTapped:
      state.isLoading = true
      return .run { send in
        let (data, _) = try await URLSession.shared
          .data(from: URL("http://numbersapi.com/\(state.count)")!)
        let fact = String(decoding: data, as: UTF8.self)
      }

    case .incrementButtonTapped:
      state.count += 1
      return .none
    }
  }
}
