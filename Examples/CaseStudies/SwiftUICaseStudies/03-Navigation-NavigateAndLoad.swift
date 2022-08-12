import Combine
import ComposableArchitecture
import SwiftUI
import UIKit

private let readMe = """
  This screen demonstrates navigation that depends on loading optional state.

  Tapping "Load optional counter" simultaneously navigates to a screen that depends on optional \
  counter state and fires off an effect that will load this state a second later.
  """

struct NavigateAndLoad: ReducerProtocol {
  struct State: Equatable {
    var isNavigationActive = false
    var optionalCounter: Counter.State?
  }
  
  enum Action: Equatable {
    case optionalCounter(Counter.Action)
    case setNavigation(isActive: Bool)
    case setNavigationIsActiveDelayCompleted
  }
  
  @Dependency(\.mainQueue) var mainQueue

  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      enum CancelID {}

      switch action {
      case .setNavigation(isActive: true):
        state.isNavigationActive = true
        return .task {
          try await self.mainQueue.sleep(for: 1)
          return .setNavigationIsActiveDelayCompleted
        }
        .cancellable(id: CancelID.self)

      case .setNavigation(isActive: false):
        state.isNavigationActive = false
        state.optionalCounter = nil
        return .cancel(id: CancelID.self)

      case .setNavigationIsActiveDelayCompleted:
        state.optionalCounter = Counter.State()
        return .none

      case .optionalCounter:
        return .none
      }
    }
    .ifLet(\.optionalCounter, action: /Action.optionalCounter) {
      Counter()
    }
  }
}

struct NavigateAndLoadView: View {
  let store: StoreOf<NavigateAndLoad>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Section {
          AboutView(readMe: readMe)
        }
        NavigationLink(
          destination: IfLetStore(
            self.store.scope(
              state: \.optionalCounter,
              action: NavigateAndLoad.Action.optionalCounter
            )
          ) {
            CounterView(store: $0)
          } else: {
            ProgressView()
          },
          isActive: viewStore.binding(
            get: \.isNavigationActive,
            send: NavigateAndLoad.Action.setNavigation(isActive:)
          )
        ) {
          Text("Load optional counter")
        }
      }
    }
    .navigationTitle("Navigate and load")
  }
}

struct NavigateAndLoadView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      NavigateAndLoadView(
        store: Store(
          initialState: NavigateAndLoad.State(),
          reducer: NavigateAndLoad()
        )
      )
    }
    .navigationViewStyle(.stack)
  }
}
