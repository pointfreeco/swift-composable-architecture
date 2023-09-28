import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates navigation that depends on loading optional data into state.

  Tapping "Load optional counter" fires off an effect that will load the counter state a second \
  later. When the counter state is present, you will be programmatically presented a sheet that \
  depends on this data.
  """

// MARK: - Feature domain

struct LoadThenPresent: Reducer {
  @ObservableState
  struct State: Equatable {
    @ObservationStateIgnored
    @PresentationState var counter: Counter.State?
    var isActivityIndicatorVisible = false
  }

  enum Action {
    case counter(PresentationAction<Counter.Action>)
    case counterButtonTapped
    case counterPresentationDelayCompleted
  }

  @Dependency(\.continuousClock) var clock

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
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
        state.counter = Counter.State()
        return .none

      }
    }
    .ifLet(\.$counter, action: /Action.counter) {
      Counter()
    }
  }
}

// MARK: - Feature view

struct LoadThenPresentView: View {
  let store: StoreOf<LoadThenPresent>

  var body: some View {
    Form {
      Section {
        AboutView(readMe: readMe)
      }

      Button {
        self.store.send(.counterButtonTapped)
      } label: {
        HStack {
          Text("Load optional counter")
          if self.store.isActivityIndicatorVisible {
            Spacer()
            ProgressView()
          }
        }
      }

      Section {
        if let count = self.store.counter?.count {
          Text("\(count)")
        }
      }
    }
    .sheet(
      store: self.store.scope(state: \.$counter, action: LoadThenPresent.Action.counter),
      content: { store in
        CounterView.init(store: store)
          .presentationDetents([.medium])
      }
    )
    .navigationTitle("Load and present")
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
