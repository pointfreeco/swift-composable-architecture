import Combine
import ComposableArchitecture
import SwiftUI
import UIKit

private let readMe = """
  This screen demonstrates navigation that depends on loading optional state.

  Tapping "Load optional counter" simultaneously navigates to a screen that depends on optional \
  counter state and fires off an effect that will load this state a second later.
  """

struct NavigateAndLoadState: Equatable {
  var isNavigationActive = false
  var optionalCounter: CounterState?
}

enum NavigateAndLoadAction: Equatable {
  case optionalCounter(CounterAction)
  case setNavigation(isActive: Bool)
  case setNavigationIsActiveDelayCompleted
}

struct NavigateAndLoadEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

let navigateAndLoadReducer =
  counterReducer
  .optional()
  .pullback(
    state: \.optionalCounter,
    action: /NavigateAndLoadAction.optionalCounter,
    environment: { _ in CounterEnvironment() }
  )
  .combined(
    with: Reducer<
      NavigateAndLoadState, NavigateAndLoadAction, NavigateAndLoadEnvironment
    > { state, action, environment in

      enum CancelID {}

      switch action {
      case .setNavigation(isActive: true):
        state.isNavigationActive = true
        return .task {
          try await environment.mainQueue.sleep(for: 1)
          return .setNavigationIsActiveDelayCompleted
        }
        .cancellable(id: CancelID.self)

      case .setNavigation(isActive: false):
        state.isNavigationActive = false
        state.optionalCounter = nil
        return .cancel(id: CancelID.self)

      case .setNavigationIsActiveDelayCompleted:
        state.optionalCounter = CounterState()
        return .none

      case .optionalCounter:
        return .none
      }
    }
  )

struct NavigateAndLoadView: View {
  let store: Store<NavigateAndLoadState, NavigateAndLoadAction>

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
              action: NavigateAndLoadAction.optionalCounter
            )
          ) {
            CounterView(store: $0)
          } else: {
            ProgressView()
          },
          isActive: viewStore.binding(
            get: \.isNavigationActive,
            send: NavigateAndLoadAction.setNavigation(isActive:)
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
          initialState: NavigateAndLoadState(),
          reducer: navigateAndLoadReducer,
          environment: NavigateAndLoadEnvironment(
            mainQueue: .main
          )
        )
      )
    }
    .navigationViewStyle(.stack)
  }
}
