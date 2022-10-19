import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates navigation that depends on loading optional state.

  Tapping "Load optional counter" simultaneously navigates to a screen that depends on optional \
  counter state and fires off an effect that will load this state a second later.
  """

// MARK: - Feature domain

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

  @Dependency(\.continuousClock) var clock
  private enum CancelID {}

  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .setNavigation(isActive: true):
        state.isNavigationActive = true
        return .task {
          try await self.clock.sleep(for: .seconds(1))
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

// MARK: - Feature view

struct NavigateAndLoadView: View {
  let store: StoreOf<NavigateAndLoad>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
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

// MARK: - SwiftUI previews

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
