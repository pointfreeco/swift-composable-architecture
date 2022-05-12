import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates navigation that depends on loading optional state.

  Tapping "Load optional counter" fires off an effect that will load the counter state a second \
  later. When the counter state is present, you will be programmatically navigated to the screen \
  that depends on this data.
  """

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
      case .onDisappear:
        return .cancel(id: CancelId.self)

      case .setNavigation(isActive: true):
        state.isActivityIndicatorVisible = true
        return Effect(value: .setNavigationIsActiveDelayCompleted)
          .delay(for: 1, scheduler: self.mainQueue)
          .eraseToEffect()
          .cancellable(id: CancelId.self)

      case .setNavigation(isActive: false):
        state.optionalCounter = nil
        return .none

      case .setNavigationIsActiveDelayCompleted:
        state.isActivityIndicatorVisible = false
        state.optionalCounter = .init()
        return .none

      case .optionalCounter:
        return .none
      }
    }
  }
}

struct LoadThenNavigateView: View {
  let store: Store<LoadThenNavigate.State, LoadThenNavigate.Action>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Section(header: Text(readMe)) {
          NavigationLink(
            destination: IfLetStore(
              self.store.scope(
                state: \.optionalCounter,
                action: LoadThenNavigate.Action.optionalCounter
              ),
              then: CounterView.init(store:)
            ),
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
          initialState: .init(),
          reducer: LoadThenNavigate()
        )
      )
    }
    .navigationViewStyle(.stack)
  }
}
