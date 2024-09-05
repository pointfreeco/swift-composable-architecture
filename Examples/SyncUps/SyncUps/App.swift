import ComposableArchitecture
import SwiftUI

@main
struct TCATestApp: App {
  var body: some Scene {
    WindowGroup {
      DeadlockView(store: Store(initialState: Deadlock.State(), reducer: {
        Deadlock()
      }))
    }
  }
}

struct DeadlockView: View {
  @Bindable var store: StoreOf<Deadlock>
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    NavigationSplitView {
      List(selection: $store.selection) {
        NavigationLink(value: "child") {
          Text("Go To Child")
        }
      }
      .navigationTitle("Home")
      .listStyle(.sidebar)
      .task {
        await store.send(.task).finish()
      }
    } detail: {
      NavigationStack {
        switch store.destination {
        case .child:
          if let store = store.scope(state: \.destination?.child, action: \.destination.child) {
            ChildView(store: store)
          }
        default:
          EmptyView()
        }
      }
    }
  }
}


@Reducer
struct Deadlock {
  @Reducer(state: .equatable)
  enum Destination {
    case child(Child)
  }

  @ObservableState
  struct State: Equatable {
    var selection: String? = "child"
    @Presents var destination: Destination.State? = .child(Child.State())
    @Shared(.appStorage("test")) var test: Bool = false
  }

  enum Action: BindableAction {
    case task
    case destination(PresentationAction<Destination.Action>)
    case binding(BindingAction<State>)
  }

  @Dependency(\.database) var database

  var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .task:
        return .merge(
          .run { _ in
            print("Querying database…")
            await database.query()
            print("… query complete")
          }.cancellable(id: CancelId.one, cancelInFlight: true)
        )

      case .destination, .binding:
        return .none
      }
    }
    .ifLet(\.$destination, action: \.destination)
  }

  private enum CancelId {
    case one
  }
}

@Reducer
struct Child {
  @ObservableState
  struct State: Equatable {
    @Shared(.appStorage("count")) var count: Int = 0
  }

  enum Action {
    case incrementButtonTapped
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .incrementButtonTapped:
        state.count += 1
        return .none
      }
    }
  }
}

struct ChildView: View {
  let store: StoreOf<Child>

  var body: some View {
    VStack {
      Text(store.count.formatted())
        .navigationTitle("Child")
      Button("Increment") {
        store.send(.incrementButtonTapped)
      }
      .buttonStyle(.borderedProminent)
    }
  }
}


struct Database: DependencyKey {
  init() {
    print("Database init() start")
    UserDefaults.standard.set("foo-bar", forKey: "test-key")
    // Will never be called, will deadlock on the UserDefaults notification
    print("Database init() end")
  }

  func query() async {}

  static var liveValue: Database = Database()
}

extension DependencyValues {
  var database: Database {
    get { self[Database.self] }
    set { self[Database.self] = newValue }
  }
}
