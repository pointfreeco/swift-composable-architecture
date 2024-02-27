import ComposableArchitecture
import SwiftUI

private let readMe = """
  This case study demonstrates how you can use the `\\.defaultAppStorage` and \
  `\\.defaultFileStorage` dependencies in order to control how state is persisted with the \
  `@Shared` property wrapper.

  The changes made in this screen will be persisted across app launches, but the presented sheet \
  will get a sandboxed storage system so that changes in that view do not affect other parts of \
  the app. This can be handy for demo'ing parts of your application, such as in onboarding, \
  without the external storage system being changed.
  """
private let sheetReadMe = """
  In this sheet the user defaults and file system have been sandboxed from the parent view. Any \
  changes made to this state will not be saved to the real user defaults or file system.
  """

@Reducer
struct SharedStateSandboxing {
  @ObservableState
  struct State {
    @Shared(.appStorageCount) var appStorageCount = 0
    @Shared(.fileStorageCount) var fileStorageCount = 0
    @Presents var sandboxed: SharedStateSandboxing.State?
  }
  enum Action {
    case incrementAppStorage
    case incrementFileStorage
    case presentButtonTapped
    case sandboxed(PresentationAction<SharedStateSandboxing.Action>)
  }
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .incrementAppStorage:
        state.appStorageCount += 1
        return .none
      case .incrementFileStorage:
        state.fileStorageCount += 1
        return .none
      case .presentButtonTapped:
        state.sandboxed = withDependencies {
          let suiteName = "sandbox"
          let defaultAppStorage = UserDefaults(suiteName: suiteName)!
          defaultAppStorage.removePersistentDomain(forName: suiteName)
          $0.defaultAppStorage = defaultAppStorage
          $0.defaultFileStorage = MockFileStorage()
        } operation: {
          var s = SharedStateSandboxing.State()
//          s.$fileStorageCount = Shared(wrappedValue: 0, .fileStorage(URL(filePath: "/file.json")))
          return s
        }
        return .none
      case .sandboxed:
        return .none
      }
    }
    .ifLet(\.$sandboxed, action: \.sandboxed) {
      SharedStateSandboxing()
    }
  }
}

struct SharedStateSandboxingView: View {
  @Environment(\.dismiss) private var dismiss
  var isPresented = false
  @Bindable var store = Store(initialState: SharedStateSandboxing.State()) {
    SharedStateSandboxing()
  }

  var body: some View {
    Form {
      if !isPresented {
        Text(template: readMe, .caption)
      } else {
        Text(template: sheetReadMe, .caption)
      }

      Section {
        HStack {
          Text(store.appStorageCount.description)
          Spacer()
          Button("Increment") { store.send(.incrementAppStorage) }
        }
      } header: {
        Text("App storage")
      }

      Section {
        HStack {
          Text(store.fileStorageCount.description)
          Spacer()
          Button("Increment") { store.send(.incrementFileStorage) }
        }
      } header: {
        Text("File storage")
      }

      if !isPresented {
        Section {
          Button("Present sandbox") { store.send(.presentButtonTapped) }
        }
        .sheet(item: $store.scope(state: \.sandboxed, action: \.sandboxed)) { store in
          NavigationStack {
            SharedStateSandboxingView(isPresented: true, store: store)
          }
        }
      }
    }
    .toolbar {
      if isPresented {
        ToolbarItem {
          Button("Dismiss") { dismiss() }
        }
      }
    }
  }
}

extension PersistenceKey where Self == AppStorageKey<Int> {
  static var appStorageCount: Self {
    Self("appStorageCount")
  }
}
extension PersistenceKey where Self == FileStorageKey<Int> {
  static var fileStorageCount: Self {
    Self(url: URL.documentsDirectory.appending(path: "fileStorageCount.json"))
  }
}

#Preview {
  SharedStateSandboxingView()
}


//
//struct SharedStateInMemoryView: View {
//  @Bindable var store: StoreOf<SharedStateInMemory>
//
//  var body: some View {
//    TabView(selection: $store.currentTab.sending(\.selectTab)) {
//      CounterTabView(
//        store: self.store.scope(state: \.counter, action: \.counter)
//      )
//      .tag(SharedStateInMemory.Tab.counter)
//      .tabItem { Text("Counter") }
//
//      ProfileTabView(
//        store: self.store.scope(state: \.profile, action: \.profile)
//      )
//      .tag(SharedStateInMemory.Tab.profile)
//      .tabItem { Text("Profile") }
//    }
//    .navigationTitle("Shared State Demo")
//  }
//}
//
//extension SharedStateInMemory {
//  @Reducer
//  struct CounterTab {
//    @ObservableState
//    struct State: Equatable {
//      @Presents var alert: AlertState<Action.Alert>?
//      @Shared(.stats) var stats = Stats()
//    }
//
//    enum Action {
//      case alert(PresentationAction<Alert>)
//      case decrementButtonTapped
//      case incrementButtonTapped
//      case isPrimeButtonTapped
//
//      enum Alert: Equatable {}
//    }
//
//    var body: some Reducer<State, Action> {
//      Reduce { state, action in
//        switch action {
//        case .alert:
//          return .none
//
//        case .decrementButtonTapped:
//          state.stats.decrement()
//          return .none
//
//        case .incrementButtonTapped:
//          state.stats.increment()
//          return .none
//
//        case .isPrimeButtonTapped:
//          state.alert = AlertState {
//            TextState(
//              isPrime(state.stats.count)
//              ? "👍 The number \(state.stats.count) is prime!"
//              : "👎 The number \(state.stats.count) is not prime :("
//            )
//          }
//          return .none
//        }
//      }
//      .ifLet(\.$alert, action: \.alert)
//    }
//  }
//
//  @Reducer
//  struct ProfileTab {
//    @ObservableState
//    struct State: Equatable {
//      @Shared(.stats) var stats = Stats()
//    }
//
//    enum Action {
//      case resetStatsButtonTapped
//    }
//
//    var body: some Reducer<State, Action> {
//      Reduce { state, action in
//        switch action {
//        case .resetStatsButtonTapped:
//          state.stats = Stats()
//          return .none
//        }
//      }
//    }
//  }
//}
//
//private struct CounterTabView: View {
//  @Bindable var store: StoreOf<SharedStateInMemory.CounterTab>
//
//  var body: some View {
//    Form {
//      Text(template: readMe, .caption)
//
//      VStack(spacing: 16) {
//        HStack {
//          Button {
//            store.send(.decrementButtonTapped)
//          } label: {
//            Image(systemName: "minus")
//          }
//
//          Text("\(store.stats.count)")
//            .monospacedDigit()
//
//          Button {
//            store.send(.incrementButtonTapped)
//          } label: {
//            Image(systemName: "plus")
//          }
//        }
//
//        Button("Is this prime?") { store.send(.isPrimeButtonTapped) }
//      }
//    }
//    .buttonStyle(.borderless)
//    .alert($store.scope(state: \.alert, action: \.alert))
//  }
//}
//
//private struct ProfileTabView: View {
//  let store: StoreOf<SharedStateInMemory.ProfileTab>
//
//  var body: some View {
//    Form {
//      Text(
//        template: """
//          This tab shows state from the previous tab, and it is capable of resetting all of the \
//          state back to 0.
//
//          This shows that it is possible for each screen to model its state in the way that makes \
//          the most sense for it, while still allowing the state and mutations to be shared \
//          across independent screens.
//          """,
//        .caption
//      )
//
//      VStack(spacing: 16) {
//        Text("Current count: \(store.stats.count)")
//        Text("Max count: \(store.stats.maxCount)")
//        Text("Min count: \(store.stats.minCount)")
//        Text("Total number of count events: \(store.stats.numberOfCounts)")
//        Button("Reset") { store.send(.resetStatsButtonTapped) }
//      }
//    }
//    .buttonStyle(.borderless)
//  }
//}
//
//extension PersistenceKey where Self == InMemoryKey<Stats> {
//  fileprivate static var stats: Self {
//    inMemory("stats")
//  }
//}
//
///// Checks if a number is prime or not.
//private func isPrime(_ p: Int) -> Bool {
//  if p <= 1 { return false }
//  if p <= 3 { return true }
//  for i in 2...Int(sqrtf(Float(p))) {
//    if p % i == 0 { return false }
//  }
//  return true
//}
