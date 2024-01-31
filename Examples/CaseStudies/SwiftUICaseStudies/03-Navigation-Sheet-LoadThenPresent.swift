import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates navigation that depends on loading optional data into state.

  Tapping "Load optional counter" fires off an effect that will load the counter state a second \
  later. When the counter state is present, you will be programmatically presented a sheet that \
  depends on this data.
  """

@Reducer
struct LoadThenPresent {
  @ObservableState
  struct State: Equatable {
    @Presents var counter: Counter.State?
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
    .ifLet(\.$counter, action: \.counter) {
      Counter()
    }
  }
}

struct LoadThenPresentView: View {
  @Bindable var store: StoreOf<LoadThenPresent>

  var body: some View {
    Form {
      Section {
        AboutView(readMe: readMe)
      }
      Button {
        store.send(.counterButtonTapped)
      } label: {
        HStack {
          Text("Load optional counter")
          if store.isActivityIndicatorVisible {
            Spacer()
            ProgressView()
          }
        }
      }
    }
    .sheet(item: $store.scope(state: \.counter, action: \.counter)) { store in
      CounterView(store: store)
    }
    .navigationTitle("Load and present")
  }
}

#Preview {
  NavigationStack {
    LoadThenPresentView(
      store: Store(initialState: LoadThenPresent.State()) {
        LoadThenPresent()
      }
    )
  }
}
