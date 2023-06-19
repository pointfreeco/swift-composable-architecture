import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates how multiple independent screens can share state in the Composable \
  Architecture. Each tab manages its own state, and could be in separate modules, but changes in \
  one tab are immediately reflected in the other.

  This tab has its own state, consisting of a count value that can be incremented and decremented, \
  as well as an alert value that is set when asking if the current count is prime.

  Internally, it is also keeping track of various stats, such as min and max counts and total \
  number of count events that occurred. Those states are viewable in the other tab, and the stats \
  can be reset from the other tab.
  """

// MARK: - Feature domain

struct CounterData: Equatable {
  var count = 0
  var maxCount = 0
  var minCount = 0
  var numberOfCounts = 0
}

struct SharedState: ReducerProtocol {
  enum Tab { case counter, profile }

  struct State: Equatable {
    var counter = Counter.State()
    var currentTab = Tab.counter

    /// The Profile.State can be derived from the Counter.State by getting and setting the parts it
    /// cares about. This allows the profile feature to operate on a subset of app state instead of
    /// the whole thing.
    var profile: Profile.State {
      get {
        Profile.State(
          currentTab: self.currentTab,
          counter: self.counter.data
        )
      }
      set {
        self.currentTab = newValue.currentTab
        self.counter.data = newValue.counter
      }
    }
  }

  enum Action: Equatable {
    case counter(Counter.Action)
    case profile(Profile.Action)
    case selectTab(Tab)
  }

  var body: some ReducerProtocol<State, Action> {
    Scope(state: \.counter, action: /Action.counter) {
      Counter()
    }

    Scope(state: \.profile, action: /Action.profile) {
      Profile()
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

  struct Counter: ReducerProtocol {
    struct State: Equatable {
      var alert: AlertState<Action>?
      var data = CounterData()
    }

    enum Action: Equatable {
      case alertDismissed
      case decrementButtonTapped
      case incrementButtonTapped
      case isPrimeButtonTapped
    }

    func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
      switch action {
      case .alertDismissed:
        state.alert = nil
        return .none

      case .decrementButtonTapped:
        state.data.count -= 1
        state.data.numberOfCounts += 1
        state.data.minCount = min(state.data.minCount, state.data.count)
        return .none

      case .incrementButtonTapped:
        state.data.count += 1
        state.data.numberOfCounts += 1
        state.data.maxCount = max(state.data.maxCount, state.data.count)
        return .none

      case .isPrimeButtonTapped:
        state.alert = AlertState {
          TextState(
            isPrime(state.data.count)
              ? "👍 The number \(state.data.count) is prime!"
              : "👎 The number \(state.data.count) is not prime :("
          )
        }
        return .none
      }
    }
  }

  struct Profile: ReducerProtocol {
    struct State: Equatable {
      private(set) var currentTab: Tab
      private(set) var counter: CounterData

      fileprivate mutating func resetCount() {
        self.currentTab = .counter
        self.counter = CounterData()
      }
    }

    enum Action: Equatable {
      case resetCounterButtonTapped
    }

    func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
      switch action {
      case .resetCounterButtonTapped:
        state.resetCount()
        return .none
      }
    }
  }
}

// MARK: - Feature view

struct SharedStateView: View {
  let store: StoreOf<SharedState>

  var body: some View {
    WithViewStore(self.store, observe: \.currentTab) { viewStore in
      VStack {
        Picker(
          "Tab",
          selection: viewStore.binding(send: SharedState.Action.selectTab)
        ) {
          Text("Counter")
            .tag(SharedState.Tab.counter)

          Text("Profile")
            .tag(SharedState.Tab.profile)
        }
        .pickerStyle(.segmented)

        if viewStore.state == .counter {
          SharedStateCounterView(
            store: self.store.scope(state: \.counter, action: SharedState.Action.counter))
        }

        if viewStore.state == .profile {
          SharedStateProfileView(
            store: self.store.scope(state: \.profile, action: SharedState.Action.profile))
        }

        Spacer()
      }
    }
    .padding()
  }
}

struct SharedStateCounterView: View {
  let store: StoreOf<SharedState.Counter>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      VStack(spacing: 64) {
        Text(template: readMe, .caption)

        VStack(spacing: 16) {
          HStack {
            Button {
              viewStore.send(.decrementButtonTapped)
            } label: {
              Image(systemName: "minus")
            }

            Text("\(viewStore.data.count)")
              .monospacedDigit()

            Button {
              viewStore.send(.incrementButtonTapped)
            } label: {
              Image(systemName: "plus")
            }
          }

          Button("Is this prime?") { viewStore.send(.isPrimeButtonTapped) }
        }
      }
      .padding(.top)
      .navigationTitle("Shared State Demo")
      .alert(self.store.scope(state: \.alert, action: { $0 }), dismiss: .alertDismissed)
    }
  }
}

struct SharedStateProfileView: View {
  let store: StoreOf<SharedState.Profile>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      VStack(spacing: 64) {
        Text(
          template: """
            This tab shows state from the previous tab, and it is capable of reseting all of the \
            state back to 0.

            This shows that it is possible for each screen to model its state in the way that makes \
            the most sense for it, while still allowing the state and mutations to be shared \
            across independent screens.
            """,
          .caption
        )

        VStack(spacing: 16) {
          Text("Current count: \(viewStore.counter.count)")
          Text("Max count: \(viewStore.counter.maxCount)")
          Text("Min count: \(viewStore.counter.minCount)")
          Text("Total number of count events: \(viewStore.counter.numberOfCounts)")
          Button("Reset") { viewStore.send(.resetCounterButtonTapped) }
        }
      }
      .padding(.top)
      .navigationTitle("Profile")
    }
  }
}

// MARK: - SwiftUI previews

struct SharedState_Previews: PreviewProvider {
  static var previews: some View {
    SharedStateView(
      store: Store(initialState: SharedState.State()) {
        SharedState()
      }
    )
  }
}

// MARK: - Private helpers

/// Checks if a number is prime or not.
private func isPrime(_ p: Int) -> Bool {
  if p <= 1 { return false }
  if p <= 3 { return true }
  for i in 2...Int(sqrtf(Float(p))) {
    if p % i == 0 { return false }
  }
  return true
}
