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
    Pullback(state: \.optionalCounter, action: /Action.optionalCounter) {
      IfLetReducer {
        Counter()
      }
    }

    Reduce { state, action in
      enum CancelId {}

      switch action {
      case .setNavigation(isActive: true):
        state.isNavigationActive = true
        return .task {
          try? await self.mainQueue.sleep(for: 1)
          return .setNavigationIsActiveDelayCompleted
        }
        .cancellable(id: CancelId.self)

      case .setNavigation(isActive: false):
        state.isNavigationActive = false
        state.optionalCounter = nil
        return .cancel(id: CancelId.self)

      case .setNavigationIsActiveDelayCompleted:
        state.optionalCounter = .init()
        return .none

      case .optionalCounter:
        return .none
      }
    }
  }
}

struct NavigateAndLoadView: View {
  let store: StoreOf<NavigateAndLoad>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Section(header: Text(readMe)) {
          NavigationLink(
            destination: IfLetStore(
              self.store.scope(
                state: \.optionalCounter,
                action: NavigateAndLoad.Action.optionalCounter
              ),
              then: CounterView.init(store:),
              else: ProgressView.init
            ),
            isActive: viewStore.binding(
              get: \.isNavigationActive,
              send: NavigateAndLoad.Action.setNavigation(isActive:)
            )
          ) {
            HStack {
              Text("Load optional counter")
            }
          }
        }
      }
    }
    .navigationBarTitle("Navigate and load")
  }
}

struct NavigateAndLoadView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      NavigateAndLoadView(
        store: Store(
          initialState: .init(),
          reducer: NavigateAndLoad()
        )
      )
    }
    .navigationViewStyle(.stack)
  }
}
