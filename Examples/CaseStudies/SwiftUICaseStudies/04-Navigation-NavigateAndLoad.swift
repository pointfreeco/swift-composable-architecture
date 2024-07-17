import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates navigation that depends on loading optional state.

  Tapping "Load optional counter" simultaneously navigates to a screen that depends on optional \
  counter state and fires off an effect that will load this state a second later.
  """

@Reducer
struct NavigateAndLoad {
  @ObservableState
  struct State: Equatable {
    var isNavigationActive = false
    var optionalCounter: Counter.State?
  }

  enum Action {
    case optionalCounter(Counter.Action)
    case setNavigation(isActive: Bool)
    case setNavigationIsActiveDelayCompleted
  }

  @Dependency(\.continuousClock) var clock
  private enum CancelID { case load }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .setNavigation(isActive: true):
        state.isNavigationActive = true
        return .run { send in
          try await self.clock.sleep(for: .seconds(1))
          await send(.setNavigationIsActiveDelayCompleted)
        }
        .cancellable(id: CancelID.load)

      case .setNavigation(isActive: false):
        state.isNavigationActive = false
        state.optionalCounter = nil
        return .cancel(id: CancelID.load)

      case .setNavigationIsActiveDelayCompleted:
        state.optionalCounter = Counter.State()
        return .none

      case .optionalCounter:
        return .none
      }
    }
    .ifLet(\.optionalCounter, action: \.optionalCounter) {
      Counter()
    }
  }
}

struct NavigateAndLoadView: View {
  @Bindable var store: StoreOf<NavigateAndLoad>

  var body: some View {
    Form {
      Section {
        AboutView(readMe: readMe)
      }
      NavigationLink(
        "Load optional counter",
        isActive: $store.isNavigationActive.sending(\.setNavigation)
      ) {
        if let store = store.scope(state: \.optionalCounter, action: \.optionalCounter) {
          CounterView(store: store)
        } else {
          ProgressView()
        }
      }
    }
    .navigationTitle("Navigate and load")
  }
}

#Preview {
  NavigationView {
    NavigateAndLoadView(
      store: Store(initialState: NavigateAndLoad.State()) {
        NavigateAndLoad()
      }
    )
  }
  .navigationViewStyle(.stack)
}
