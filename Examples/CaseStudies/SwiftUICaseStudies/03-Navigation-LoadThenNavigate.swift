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
    @PresentationStateOf<Counter> var counter
    var isActivityIndicatorVisible = false
  }

  enum Action: Equatable {
    case counter(PresentationActionOf<Counter>)
    case loadCounterButtonTapped
    case presentationDelayCompleted
  }

  @Dependency(\.continuousClock) var clock

  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .counter:
        return .none

      case .loadCounterButtonTapped:
        state.isActivityIndicatorVisible = true
        return .task {
          try await self.clock.sleep(for: .seconds(1))
          return .presentationDelayCompleted
        }

      case .presentationDelayCompleted:
        state.counter = Counter.State()
        state.isActivityIndicatorVisible = false
        return .none
      }
    }
    .presentationDestination(\.$counter, action: /Action.counter) {
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
        Button {
          viewStore.send(.loadCounterButtonTapped)
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
      .navigationDestination(
        store: self.store.scope(state: \.$counter, action: LoadThenNavigate.Action.counter),
        destination: CounterView.init(store:)
      )
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
