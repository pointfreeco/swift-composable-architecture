import ComposableArchitecture
import SwiftUI

struct PullToRefreshState: Equatable {
  var count = 0
  var fact: String?
  var isLoading = false
}

enum PullToRefreshAction {
  case decrementButtonTapped
  case incrementButtonTapped
  case numberFactResponse(Result<String, NumbersApiError>)
  case refresh
}

struct PullToRefreshEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var numberFact: (Int) -> Effect<String, NumbersApiError>
}

let pullToRefreshReducer = Reducer<
  PullToRefreshState,
  PullToRefreshAction,
  PullToRefreshEnvironment
> { state, action, environment in
  switch action {
  case .decrementButtonTapped:
    state.count -= 1
    state.fact = nil
    return .none

  case .incrementButtonTapped:
    state.count += 1
    state.fact = nil
    return .none

  case let .numberFactResponse(.success(fact)):
    state.fact = fact
    state.isLoading = false
    return .none

  case .numberFactResponse(.failure):
    state.isLoading = false
    return .none

  case .refresh:
    state.fact = nil
    state.isLoading = true
    return environment.numberFact(state.count)
      .delay(for: 2, scheduler: environment.mainQueue.animation())
      .catchToEffect()
      .map(PullToRefreshAction.numberFactResponse)
  }
}
  .debug()

struct PullToRefreshView: View {
  let store: Store<PullToRefreshState, PullToRefreshAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      List {
        HStack {
          Button("-") { viewStore.send(.decrementButtonTapped, animation: .default) }
          Text("\(viewStore.count)")
          Button("+") { viewStore.send(.incrementButtonTapped, animation: .default) }
        }
        .buttonStyle(.plain)

        if let fact = viewStore.fact {
          Text(fact)
        }
      }
      .refreshable {
        await viewStore.send(.refresh, while: \.isLoading)
      }
    }
  }
}

struct PullToRefresh_Previews: PreviewProvider {
  static var previews: some View {
    PullToRefreshView(
      store: .init(
        initialState: .init(),
        reducer: pullToRefreshReducer,
        environment: PullToRefreshEnvironment(
          mainQueue: .main,
          numberFact: liveNumberFact(for:)
        )
      )
    )
  }
}
