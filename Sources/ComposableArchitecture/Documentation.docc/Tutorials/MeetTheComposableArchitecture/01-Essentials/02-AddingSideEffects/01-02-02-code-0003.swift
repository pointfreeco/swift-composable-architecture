import ComposableArchitecture

@Reducer
struct CounterFeature {
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
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .decrementButtonTapped:
        state.count -= 1
        state.fact = nil
        return .none
        
      case .factButtonTapped:
        state.fact = nil
        state.isLoading = true
        return .run { [count = state.count] send in
          let (data, _) = try await URLSession.shared
            .data(from: URL(string: "http://numbersapi.com/\(count)")!)
          let fact = String(decoding: data, as: UTF8.self)
          state.fact = fact
          // 🛑 Mutable capture of 'inout' parameter 'state' is not allowed in
          //    concurrently-executing code
        }
        
      case .incrementButtonTapped:
        state.count += 1
        state.fact = nil
        return .none
      }
    }
  }
}
