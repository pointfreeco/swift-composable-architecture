import Combine
import ComposableArchitecture
import SwiftUI

struct PullToRefreshState: Equatable {
  var count = 0
  var fact: String?
  var isLoading = false
}

enum PullToRefreshAction: Equatable {
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
    state.isLoading = false
    return .cancel(id: CancelId())
    
  case let .factResponse(.success(fact)):
    state.isLoading = false
    state.fact = fact
    return .none
    
  case .factResponse(.failure):
    state.isLoading = false
    // TODO: do some error handling
    return .none
    
  case .decrementButtonTapped:
    state.count -= 1
    return .none
    
  case .incrementButtonTapped:
    state.count += 1
    return .none
    
  case .refresh:
    state.fact = nil
    state.isLoading = true
    return environment.fact.fetch(state.count)
//      .receive(on: environment.mainQueue)
      .delay(for: 2, scheduler: environment.mainQueue.animation())
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
        if viewStore.isLoading {
          Button("Cancel") {
            viewStore.send(.cancelButtonTapped, animation: .default)
          }
        }
      }
      .refreshable {
        await viewStore.send(.refresh, while: \.isLoading)
      }
    }
  }
}

extension ViewStore {
  func send(
    _ action: Action,
    `while` isInFlight: @escaping (State) -> Bool
  ) async {
    self.send(action)

    await withUnsafeContinuation { (continuation: UnsafeContinuation<Void, Never>) in
      var cancellable: Cancellable?

      cancellable = self.publisher
        .filter { !isInFlight($0) }
        .prefix(1)
        .sink { _ in
          continuation.resume()
          _ = cancellable
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
