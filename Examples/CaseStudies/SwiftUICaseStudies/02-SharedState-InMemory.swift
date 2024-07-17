import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates how multiple independent screens can share state in the Composable \
  Architecture through an in-memory reference. Each tab manages its own state, and \
  could be in separate modules, but changes in one tab are immediately reflected in the other.

  This tab has its own state, consisting of a count value that can be incremented and decremented, \
  as well as an alert value that is set when asking if the current count is prime.

  Internally, it is also keeping track of various stats, such as min and max counts and total \
  number of count events that occurred. Those states are viewable in the other tab, and the stats \
  can be reset from the other tab.
  """

@Reducer
struct SharedStateInMemory {
  enum Tab { case counter, profile }

  @ObservableState
  struct State: Equatable {
    var currentTab = Tab.counter
    var counter = CounterTab.State()
    var profile = ProfileTab.State()
  }

  enum Action {
    case counter(CounterTab.Action)
    case profile(ProfileTab.Action)
    case selectTab(Tab)
  }

  var body: some Reducer<State, Action> {
    Scope(state: \.counter, action: \.counter) {
      CounterTab()
    }

    Scope(state: \.profile, action: \.profile) {
      ProfileTab()
    }

    Reduce { state, action in
      switch action {
      case .counter, .profile:
        return .none
      case let .selectTab(tab):
        state.currentTab = tab
        return .none
      }
    }
  }
}

struct SharedStateInMemoryView: View {
  @Bindable var store: StoreOf<SharedStateInMemory>

  var body: some View {
    TabView(selection: $store.currentTab.sending(\.selectTab)) {
      CounterTabView(
        store: store.scope(state: \.counter, action: \.counter)
      )
      .tag(SharedStateInMemory.Tab.counter)
      .tabItem { Text("Counter") }

      ProfileTabView(
        store: store.scope(state: \.profile, action: \.profile)
      )
      .tag(SharedStateInMemory.Tab.profile)
      .tabItem { Text("Profile") }
    }
    .navigationTitle("Shared State Demo")
  }
}

extension SharedStateInMemory {
  @Reducer
  struct CounterTab {
    @ObservableState
    struct State: Equatable {
      @Presents var alert: AlertState<Action.Alert>?
      @Shared(.stats) var stats = Stats()
    }

    enum Action {
      case alert(PresentationAction<Alert>)
      case decrementButtonTapped
      case incrementButtonTapped
      case isPrimeButtonTapped

      enum Alert: Equatable {}
    }

    var body: some Reducer<State, Action> {
      Reduce { state, action in
        switch action {
        case .alert:
          return .none

        case .decrementButtonTapped:
          state.stats.decrement()
          return .none

        case .incrementButtonTapped:
          state.stats.increment()
          return .none

        case .isPrimeButtonTapped:
          state.alert = AlertState {
            TextState(
              isPrime(state.stats.count)
                ? "👍 The number \(state.stats.count) is prime!"
                : "👎 The number \(state.stats.count) is not prime :("
            )
          }
          return .none
        }
      }
      .ifLet(\.$alert, action: \.alert)
    }
  }

  @Reducer
  struct ProfileTab {
    @ObservableState
    struct State: Equatable {
      @Shared(.stats) var stats = Stats()
    }

    enum Action {
      case resetStatsButtonTapped
    }

    var body: some Reducer<State, Action> {
      Reduce { state, action in
        switch action {
        case .resetStatsButtonTapped:
          state.stats = Stats()
          return .none
        }
      }
    }
  }
}

private struct CounterTabView: View {
  @Bindable var store: StoreOf<SharedStateInMemory.CounterTab>

  var body: some View {
    Form {
      Text(template: readMe, .caption)

      VStack(spacing: 16) {
        HStack {
          Button {
            store.send(.decrementButtonTapped)
          } label: {
            Image(systemName: "minus")
          }

          Text("\(store.stats.count)")
            .monospacedDigit()

          Button {
            store.send(.incrementButtonTapped)
          } label: {
            Image(systemName: "plus")
          }
        }

        Button("Is this prime?") { store.send(.isPrimeButtonTapped) }
      }
    }
    .buttonStyle(.borderless)
    .alert($store.scope(state: \.alert, action: \.alert))
  }
}

private struct ProfileTabView: View {
  let store: StoreOf<SharedStateInMemory.ProfileTab>

  var body: some View {
    Form {
      Text(
        template: """
          This tab shows state from the previous tab, and it is capable of resetting all of the \
          state back to 0.

          This shows that it is possible for each screen to model its state in the way that makes \
          the most sense for it, while still allowing the state and mutations to be shared \
          across independent screens.
          """,
        .caption
      )

      VStack(spacing: 16) {
        Text("Current count: \(store.stats.count)")
        Text("Max count: \(store.stats.maxCount)")
        Text("Min count: \(store.stats.minCount)")
        Text("Total number of count events: \(store.stats.numberOfCounts)")
        Button("Reset") { store.send(.resetStatsButtonTapped) }
      }
    }
    .buttonStyle(.borderless)
  }
}

#Preview {
  SharedStateInMemoryView(
    store: Store(initialState: SharedStateInMemory.State()) { SharedStateInMemory() }
  )
}

extension PersistenceReaderKey where Self == InMemoryKey<Stats> {
  fileprivate static var stats: Self {
    inMemory("stats")
  }
}

/// Checks if a number is prime or not.
private func isPrime(_ p: Int) -> Bool {
  if p <= 1 { return false }
  if p <= 3 { return true }
  for i in 2...Int(sqrtf(Float(p))) {
    if p % i == 0 { return false }
  }
  return true
}
