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

extension Dependency: Equatable where Value: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.wrappedValue == rhs.wrappedValue
  }
}

@Reducer
struct SharedState {
  enum Tab { case counter, profile }

  @ObservableState
  struct State: Equatable {
    @ObservationStateIgnored
    @Dependency(Shared<SharedState.Counter.State>.self) var counter
    //@Dependency(SharedState.Counter.State.self) var counter
    var profile: Profile.State
    var currentTab: Tab

    init(currentTab: Tab = .counter) {
      self.currentTab = currentTab
      self.profile = Profile.State()
    }
  }

  enum Action {
    case counter(Counter.Action)
    case profile(Profile.Action)
    case selectTab(Tab)
  }

  var body: some Reducer<State, Action> {
    Scope(state: \.counter.value, action: \.counter) {
      Counter()
    }

    Scope(state: \.profile, action: \.profile) {
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

  @Reducer
  struct Counter {
    @ObservableState
    struct State: Equatable {
      @Presents var alert: AlertState<Action.Alert>?
      var count = 0
      var maxCount = 0
      var minCount = 0
      var numberOfCounts = 0
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
          state.count -= 1
          state.numberOfCounts += 1
          state.minCount = min(state.minCount, state.count)
          return .none

        case .incrementButtonTapped:
          state.count += 1
          state.numberOfCounts += 1
          state.maxCount = max(state.maxCount, state.count)
          return .none

        case .isPrimeButtonTapped:
          state.alert = AlertState {
            TextState(
              isPrime(state.count)
                ? "👍 The number \(state.count) is prime!"
                : "👎 The number \(state.count) is not prime :("
            )
          }
          return .none
        }
      }
      .ifLet(\.$alert, action: \.alert)
    }
  }

  @Reducer
  struct Profile {
    @ObservableState
    struct State: Equatable {
      @ObservationStateIgnored
      @Dependency(Shared<SharedState.Counter.State>.self) var counter

//      // NB: This initializer is required in Xcode 15.0.1 (which CI uses at the time of writing
//      //     this). We can remove when Xcode 15.1 is released and CI uses it.
//      #if swift(<5.9.2)
//        init(currentTab: Tab, count: Int = 0, maxCount: Int, minCount: Int, numberOfCounts: Int) {
//          self.currentTab = currentTab
//          self.count = count
//          self.maxCount = maxCount
//          self.minCount = minCount
//          self.numberOfCounts = numberOfCounts
//        }
//      #endif

      fileprivate mutating func resetCount() {
        self.counter.value = Counter.State()
      }
    }

    enum Action {
      case resetCounterButtonTapped
    }

    var body: some Reducer<State, Action> {
      Reduce { state, action in
        switch action {
        case .resetCounterButtonTapped:
          state.resetCount()
          return .none
        }
      }
    }
  }
}

// MARK: - Feature view

struct SharedStateView: View {
  @Bindable var store = Store(initialState: SharedState.State()) {
    SharedState()
      ._printChanges()
  } withDependencies: {
    $0[Shared<SharedState.Counter.State>.self] = Shared(SharedState.Counter.State())
  }

  var body: some View {
    VStack {
      Picker("Tab", selection: $store.currentTab.sending(\.selectTab)) {
        Text("Counter")
          .tag(SharedState.Tab.counter)

        Text("Profile")
          .tag(SharedState.Tab.profile)
      }
      .pickerStyle(.segmented)

      switch store.currentTab {
      case .counter:
        SharedStateCounterView(
          store: store.scope(state: \.counter.value, action: \.counter)
        )

      case .profile:
        SharedStateProfileView(
          store: store.scope(state: \.profile, action: \.profile)
        )
      }

      Spacer()
    }
    .padding()
  }
}

struct SharedStateCounterView: View {
  @Bindable var store: StoreOf<SharedState.Counter>

  var body: some View {
    VStack(spacing: 64) {
      Text(template: readMe, .caption)

      VStack(spacing: 16) {
        HStack {
          Button {
            store.send(.decrementButtonTapped)
          } label: {
            Image(systemName: "minus")
          }

          Text("\(store.count)")
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
    .padding(.top)
    .navigationTitle("Shared State Demo")
    .alert($store.scope(state: \.alert, action: \.alert))
  }
}

struct SharedStateProfileView: View {
  let store: StoreOf<SharedState.Profile>

  var body: some View {
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
        Text("Current count: \(store.counter.count)")
        Text("Max count: \(store.counter.maxCount)")
        Text("Min count: \(store.counter.minCount)")
        Text("Total number of count events: \(store.counter.numberOfCounts)")
        Button("Reset") { store.send(.resetCounterButtonTapped) }
      }
    }
    .padding(.top)
    .navigationTitle("Profile")
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
