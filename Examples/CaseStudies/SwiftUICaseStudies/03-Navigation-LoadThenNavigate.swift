import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates navigation that depends on loading optional state.

  Tapping "Load optional counter" fires off an effect that will load the counter state a second \
  later. When the counter state is present, you will be programmatically navigated to the screen \
  that depends on this data.
  """

struct LoadThenNavigateState: Equatable {
  var optionalCounter: CounterState?
  var isActivityIndicatorVisible = false

  var isNavigationActive: Bool { self.optionalCounter != nil }
}

enum LoadThenNavigateAction: Equatable {
  case onDisappear
  case optionalCounter(CounterAction)
  case setNavigation(isActive: Bool)
  case setNavigationIsActiveDelayCompleted
}

struct LoadThenNavigateEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

let loadThenNavigateReducer =
  counterReducer
  .optional()
  .pullback(
    state: \.optionalCounter,
    action: /LoadThenNavigateAction.optionalCounter,
    environment: { _ in CounterEnvironment() }
  )
  .combined(
    with: Reducer<
      LoadThenNavigateState, LoadThenNavigateAction, LoadThenNavigateEnvironment
    > { state, action, environment in

      enum CancelId {}

      switch action {
      case .onDisappear:
        return .cancel(id: CancelId.self)

      case .setNavigation(isActive: true):
        state.isActivityIndicatorVisible = true
        return Effect(value: .setNavigationIsActiveDelayCompleted)
          .delay(for: 1, scheduler: environment.mainQueue)
          .eraseToEffect()
          .cancellable(id: CancelId.self)

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

struct LoadThenNavigateView: View {
  let store: Store<LoadThenNavigateState, LoadThenNavigateAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Section(header: Text(readMe)) {
          NavigationLink(
            destination: IfLetStore(
              self.store.scope(
                state: \.optionalCounter,
                action: LoadThenNavigateAction.optionalCounter
              ),
              then: CounterView.init(store:)
            ),
            isActive: viewStore.binding(
              get: \.isNavigationActive,
              send: LoadThenNavigateAction.setNavigation(isActive:)
            )
          ) {
            HStack {
              Text("Load optional counter")
              if viewStore.isActivityIndicatorVisible {
                Spacer()
                ProgressView()
              }
            }
          }
        }
      }
      .onDisappear { viewStore.send(.onDisappear) }
    }
    .navigationBarTitle("Load then navigate")
  }
}

struct LoadThenNavigateView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      LoadThenNavigateView(
        store: Store(
          initialState: LoadThenNavigateState(),
          reducer: loadThenNavigateReducer,
          environment: LoadThenNavigateEnvironment(
            mainQueue: .main
          )
        )
      )
    }
    .navigationViewStyle(.stack)
  }
}
