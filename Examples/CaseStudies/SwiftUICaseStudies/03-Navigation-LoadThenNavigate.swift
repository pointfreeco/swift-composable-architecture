import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates navigation that depends on loading optional state.

  Tapping "Load optional counter" fires off an effect that will load the counter state a second \
  later. When the counter state is present, you will be programmatically navigated to the screen \
  that depends on this data.
  """

// MARK: - Feature domain

struct LoadThenNavigate: ReducerProtocol {
  struct State: Equatable {
    var optionalCounter: Counter.State?
    var isActivityIndicatorVisible = false

    var isNavigationActive: Bool { self.optionalCounter != nil }
  }

  enum Action: Equatable {
    case onDisappear
    case optionalCounter(Counter.Action)
    case setNavigation(isActive: Bool)
    case setNavigationIsActiveDelayCompleted
  }

  @Dependency(\.continuousClock) var clock
  private enum CancelID {}

  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .onDisappear:
        return .cancel(id: CancelID.self)

      case .setNavigation(isActive: true):
        state.isActivityIndicatorVisible = true
        return .task {
          try await self.clock.sleep(for: .seconds(1))
          return .setNavigationIsActiveDelayCompleted
        }
        .cancellable(id: CancelID.self)

      case .setNavigation(isActive: false):
        state.optionalCounter = nil
        return .none

      case .setNavigationIsActiveDelayCompleted:
        state.isActivityIndicatorVisible = false
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

struct LoadThenNavigateView: View {
  let store: StoreOf<LoadThenNavigate>

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
              action: LoadThenNavigate.Action.optionalCounter
            )
          ) {
            CounterView(store: $0)
          },
          isActive: viewStore.binding(
            get: \.isNavigationActive,
            send: LoadThenNavigate.Action.setNavigation(isActive:)
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

// MARK: - SwiftUI previews

struct LoadThenNavigateView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      LoadThenNavigateView(
        store: Store(
          initialState: LoadThenNavigate.State(),
          reducer: LoadThenNavigate()
        )
      )
    }
    .navigationViewStyle(.stack)
  }
}
