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

struct SharedState: Equatable {
  var counter = CounterState()
  var currentTab = Tab.counter

  enum Tab { case counter, profile }

  struct CounterState: Equatable {
    var alert: AlertState<SharedStateAction.CounterAction>?
    var count = 0
    var maxCount = 0
    var minCount = 0
    var numberOfCounts = 0
  }

  // The ProfileState can be derived from the CounterState by getting and setting the parts it cares
  // about. This allows the profile feature to operate on a subset of app state instead of the whole
  // thing.
  var profile: ProfileState {
    get {
      ProfileState(
        currentTab: self.currentTab,
        count: self.counter.count,
        maxCount: self.counter.maxCount,
        minCount: self.counter.minCount,
        numberOfCounts: self.counter.numberOfCounts
      )
    }
    set {
      self.currentTab = newValue.currentTab
      self.counter.count = newValue.count
      self.counter.maxCount = newValue.maxCount
      self.counter.minCount = newValue.minCount
      self.counter.numberOfCounts = newValue.numberOfCounts
    }
  }

  struct ProfileState: Equatable {
    private(set) var currentTab: Tab
    private(set) var count = 0
    private(set) var maxCount: Int
    private(set) var minCount: Int
    private(set) var numberOfCounts: Int

    fileprivate mutating func resetCount() {
      self.currentTab = .counter
      self.count = 0
      self.maxCount = 0
      self.minCount = 0
      self.numberOfCounts = 0
    }
  }
}

enum SharedStateAction: Equatable {
  case counter(CounterAction)
  case profile(ProfileAction)
  case selectTab(SharedState.Tab)

  enum CounterAction: Equatable {
    case alertDismissed
    case decrementButtonTapped
    case incrementButtonTapped
    case isPrimeButtonTapped
  }

  enum ProfileAction: Equatable {
    case resetCounterButtonTapped
  }
}

let sharedStateCounterReducer = Reducer<
  SharedState.CounterState, SharedStateAction.CounterAction, Void
> { state, action, _ in
  switch action {
  case .alertDismissed:
    state.alert = nil
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
    state.alert = .init(
      title: isPrime(state.count)
        ? .init("👍 The number \(state.count) is prime!")
        : .init("👎 The number \(state.count) is not prime :(")
    )
    return .none
  }
}

let sharedStateProfileReducer = Reducer<
  SharedState.ProfileState, SharedStateAction.ProfileAction, Void
> { state, action, _ in
  switch action {
  case .resetCounterButtonTapped:
    state.resetCount()
    return .none
  }
}

let sharedStateReducer = Reducer<SharedState, SharedStateAction, Void>.combine(
  sharedStateCounterReducer.pullback(
    state: \SharedState.counter,
    action: /SharedStateAction.counter,
    environment: { _ in () }
  ),
  sharedStateProfileReducer.pullback(
    state: \SharedState.profile,
    action: /SharedStateAction.profile,
    environment: { _ in () }
  ),
  Reducer { state, action, _ in
    switch action {
    case .counter, .profile:
      return .none
    case let .selectTab(tab):
      state.currentTab = tab
      return .none
    }
  }
)

struct SharedStateView: View {
  let store: Store<SharedState, SharedStateAction>

  var body: some View {
    WithViewStore(self.store.scope(state: \.currentTab)) { viewStore in
      VStack {
        Picker(
          "Tab",
          selection: viewStore.binding(send: SharedStateAction.selectTab)
        ) {
          Text("Counter")
            .tag(SharedState.Tab.counter)

          Text("Profile")
            .tag(SharedState.Tab.profile)
        }
        .pickerStyle(.segmented)

        if viewStore.state == .counter {
          SharedStateCounterView(
            store: self.store.scope(state: \.counter, action: SharedStateAction.counter))
        }

        if viewStore.state == .profile {
          SharedStateProfileView(
            store: self.store.scope(state: \.profile, action: SharedStateAction.profile))
        }

        Spacer()
      }
    }
    .padding()
  }
}

struct SharedStateCounterView: View {
  let store: Store<SharedState.CounterState, SharedStateAction.CounterAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      VStack(spacing: 64) {
        Text(template: readMe, .caption)

        VStack(spacing: 16) {
          HStack {
            Button("−") { viewStore.send(.decrementButtonTapped) }

            Text("\(viewStore.count)")
              .font(.body.monospacedDigit())

            Button("+") { viewStore.send(.incrementButtonTapped) }
          }

          Button("Is this prime?") { viewStore.send(.isPrimeButtonTapped) }
        }
      }
      .padding(16)
      .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
      .navigationBarTitle("Shared State Demo")
      .alert(self.store.scope(state: \.alert), dismiss: .alertDismissed)
    }
  }
}

struct SharedStateProfileView: View {
  let store: Store<SharedState.ProfileState, SharedStateAction.ProfileAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
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
          Text("Current count: \(viewStore.count)")
          Text("Max count: \(viewStore.maxCount)")
          Text("Min count: \(viewStore.minCount)")
          Text("Total number of count events: \(viewStore.numberOfCounts)")
          Button("Reset") { viewStore.send(.resetCounterButtonTapped) }
        }
      }
      .padding(16)
      .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
      .navigationBarTitle("Profile")
    }
  }
}

// MARK: - SwiftUI previews

struct SharedState_Previews: PreviewProvider {
  static var previews: some View {
    SharedStateView(
      store: Store(
        initialState: SharedState(),
        reducer: sharedStateReducer,
        environment: ()
      )
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
