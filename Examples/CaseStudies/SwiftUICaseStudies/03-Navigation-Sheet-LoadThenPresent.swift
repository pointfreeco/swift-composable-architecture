import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates navigation that depends on loading optional data into state.

  Tapping "Load optional counter" fires off an effect that will load the counter state a second \
  later. When the counter state is present, you will be programmatically presented a sheet that \
  depends on this data.
  """

// MARK: - Feature domain

enum Empty: Equatable, _EphemeralState {
  case presented
}

struct LoadThenPresent: ReducerProtocol {
  struct State: Equatable {
    @PresentationState var counter: Empty?
    var isActivityIndicatorVisible = false
    var count = 0
  }

  enum Action {
    case counter(PresentationAction<Never>)
    case counterButtonTapped
    case counterPresentationDelayCompleted
    case setCount(Int)
  }

  @Dependency(\.continuousClock) var clock

  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case let .setCount(x):
        state.count = x
        return .none
      case .counter:
        return .none

      case .counterButtonTapped:
        state.isActivityIndicatorVisible = true
        return .run { send in
          try await self.clock.sleep(for: .seconds(1))
          await send(.counterPresentationDelayCompleted)
        }

      case .counterPresentationDelayCompleted:
        state.isActivityIndicatorVisible = false
        state.counter = .presented
        return .none

      }
    }
    .ifLet(\.$counter, action: /Action.counter)
  }
}

// MARK: - Feature view

struct LoadThenPresentView: View {
  let store: StoreOf<LoadThenPresent>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      Form {
        Section {
          AboutView(readMe: readMe)
        }
        Text("Count: \(viewStore.count)")
        Button {
          viewStore.send(.counterButtonTapped)
        } label: {
          HStack {
            Text("Load optional counter")
            if viewStore.isActivityIndicatorVisible {
              Spacer()
              ProgressView()
            }
          }
        }
      }
      .sheet(
        store: store.scope(state: \.$counter, action: LoadThenPresent.Action.counter)
      ) { _ in
        CounterView(
          store: Store(initialState: Counter.State(count: 0)) {
            Counter()
            Reduce { state, action in
              .run { @MainActor [count = state.count] _ in
                viewStore.send(.setCount(count))
              }
            }
          }
        )
      }
      .navigationTitle("Load and present")
    }
  }
}

// MARK: - SwiftUI previews

struct LoadThenPresentView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      LoadThenPresentView(
        store: Store(initialState: LoadThenPresent.State()) {
          LoadThenPresent()
        }
      )
    }
  }
}
