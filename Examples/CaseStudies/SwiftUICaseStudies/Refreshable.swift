import ComposableArchitecture
import SwiftUI

struct PullToRefreshState: Equatable {
  var count = 0
  var fact = ""
}

enum PullToRefreshAction: Equatable {
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
  PullToRefreshState, PullToRefreshAction, PullToRefreshEnvironment
> { state, action, environment in
  switch action {
  case .decrementButtonTapped:
    state.count -= 1
    return .none
  case .incrementButtonTapped:
    state.count += 1
    return .none
  case .numberFactResponse(.failure):
    return .none
  case let .numberFactResponse(.success(fact)):
    state.fact = fact
    return .none
  case .refresh:
    return environment.numberFact(state.count)
      .delay(for: .seconds(2), scheduler: environment.mainQueue)
      .receive(on: environment.mainQueue)
      .catchToEffect()
      .map(PullToRefreshAction.numberFactResponse)
  }
}

struct PullToRefreshView: View {
  let store: Store<PullToRefreshState, PullToRefreshAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      List {
        HStack {
          Button("-") { viewStore.send(.decrementButtonTapped) }
          Text("\(viewStore.count)")
          Button("+") { viewStore.send(.incrementButtonTapped) }
        }
        .buttonStyle(.plain)

        Text(viewStore.fact)
      }
      .refreshable {
        viewStore.send(.refresh)
        await viewStore.receive(/PullToRefreshAction.numberFactResponse)
//        await viewStore.receive(\.fact)
      }
    }
  }
}

struct PullToRefresh_Previews: PreviewProvider {
  static var previews: some View {
    PullToRefreshView(
      store: Store(
        initialState: .init(),
        reducer: pullToRefreshReducer,
        environment: .init(
          mainQueue: .main,
          numberFact: liveNumberFact(for:)
        )
      )
    )
  }
}
