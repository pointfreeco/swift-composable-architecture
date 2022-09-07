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

      enum CancelID {}

      switch action {
      case .onDisappear:
        return .cancel(id: CancelID.self)

      case .setNavigation(isActive: true):
        state.isActivityIndicatorVisible = true
        return .task {
          try await environment.mainQueue.sleep(for: 1)
          return .setNavigationIsActiveDelayCompleted
        }
        .cancellable(id: CancelID.self)

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
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      Form {
        Section {
          AboutView(readMe: readMe)
        }
        NavigationLink(
          destination: IfLetStore(
            self.store.scope(
              state: \.optionalCounter,
              action: LoadThenNavigateAction.optionalCounter
            )
          ) {
            CounterView(store: $0)
          },
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
      .onDisappear { viewStore.send(.onDisappear) }
    }
    .navigationTitle("Load then navigate")
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
