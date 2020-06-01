import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates navigation that depends on loading optional state.

  Tapping "Load optional counter" fires off an effect that will load the counter state a second \
  later. When the counter state is present, you will be programmatically navigated to the screen \
  that depends on this data.
  """

struct LazyNavigationState: Equatable {
  var optionalCounter: CounterState?
  var isActivityIndicatorVisible = false

  var isNavigationActive: Bool { self.optionalCounter != nil }
}

enum LazyNavigationAction: Equatable {
  case optionalCounter(CounterAction)
  case setNavigation(isActive: Bool)
  case setNavigationIsActiveDelayCompleted
}

struct LazyNavigationEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

let lazyNavigationReducer = counterReducer
  .optional
  .pullback(
    state: \.optionalCounter,
    action: /LazyNavigationAction.optionalCounter,
    environment: { _ in CounterEnvironment() }
  )
  .combined(
    with: Reducer<
      LazyNavigationState, LazyNavigationAction, LazyNavigationEnvironment
    > { state, action, environment in
      switch action {
      case .setNavigation(isActive: true):
        state.isActivityIndicatorVisible = true
        return Effect(value: .setNavigationIsActiveDelayCompleted)
          .delay(for: 1, scheduler: environment.mainQueue)
          .eraseToEffect()

      case .setNavigation(isActive: false):
        state.optionalCounter = nil
        return .none

      case .setNavigationIsActiveDelayCompleted:
        state.isActivityIndicatorVisible = false
        state.optionalCounter = CounterState()
        return .none

      case .optionalCounter:
        return .none
      }
    }
  )

struct LazyNavigationView: View {
  let store: Store<LazyNavigationState, LazyNavigationAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Section(header: Text(readMe)) {
          NavigationLink(
            destination: IfLetStore(
              self.store.scope(
                state: { $0.optionalCounter }, action: LazyNavigationAction.optionalCounter),
              then: CounterView.init(store:)
            ),
            isActive: viewStore.binding(
              get: { $0.isNavigationActive },
              send: LazyNavigationAction.setNavigation(isActive:)
            )
          ) {
            HStack {
              Text("Load optional counter")
              if viewStore.isActivityIndicatorVisible {
                Spacer()
                ActivityIndicator()
              }
            }
          }
        }
      }
    }
    .navigationBarTitle("Load then navigate")
  }
}

struct LazyNavigationView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      LazyNavigationView(
        store: Store(
          initialState: LazyNavigationState(),
          reducer: lazyNavigationReducer,
          environment: LazyNavigationEnvironment(
            mainQueue: DispatchQueue.main.eraseToAnyScheduler()
          )
        )
      )
    }
    .navigationViewStyle(StackNavigationViewStyle())
  }
}
