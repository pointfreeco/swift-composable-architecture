import ComposableArchitecture
import SwiftUI

struct PullToRefreshState: Equatable {
  var count = 0
  var fact: String?
}

enum PullToRefreshAction {
  case cancelButtonTapped
  case factResponse(Result<String, FactClient.Error>)
  case decrementButtonTapped
  case incrementButtonTapped
  case refresh
}

struct PullToRefreshEnvironment {
  var fact: FactClient
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

let pullToRefreshReducer = Reducer<
  PullToRefreshState,
  PullToRefreshAction,
  PullToRefreshEnvironment
> { state, action, environment in
  
  struct CancelId: Hashable {}
  
  switch action {
  case .cancelButtonTapped:
    return .cancel(id: CancelId())
    
  case let .factResponse(.success(fact)):
    state.fact = fact
    return .none
    
  case .factResponse(.failure):
    // TODO: do some error handling
    return .none
    
  case .decrementButtonTapped:
    state.count -= 1
    return .none
    
  case .incrementButtonTapped:
    state.count += 1
    return .none
    
  case .refresh:
    return environment.fact.fetch(state.count)
//      .receive(on: environment.mainQueue)
      .delay(for: 2, scheduler: environment.mainQueue)
      .catchToEffect()
      .map(PullToRefreshAction.factResponse)
      .cancellable(id: CancelId())
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
        
        if let fact = viewStore.fact {
          Text(fact)
        }
      }
      .refreshable {
        viewStore.send(.refresh)
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
          fact: .live,
          mainQueue: .main
        )
      )
    )
  }
}
