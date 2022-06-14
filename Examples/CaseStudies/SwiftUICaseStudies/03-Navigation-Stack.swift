import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates how to use NavigationStack with Composable Architecture applications.
  """

struct NavigationStackState: Equatable, NavigableState {
  var path = NavigationState<Route>()
  var total = 0

  enum Route: Codable, Equatable, Hashable {
    case screenA(ScreenAState)
    case screenB(ScreenBState)
    case screenC(ScreenCState)
  }
}

enum NavigationStackAction: Equatable, NavigableAction {
  case goToABCButtonTapped
  case navigation(NavigationAction<NavigationStackState.Route, Route>)
  case shuffleButtonTapped

  enum Route: Equatable {
    case screenA(ScreenAAction)
    case screenB(ScreenBAction)
    case screenC(ScreenCAction)
  }
}

struct NavigationStackEnvironment {
  var fact: FactClient
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var nextId: () -> Int

  static let live = Self(
    fact: .live,
    mainQueue: .main,
    nextId: Int.incrementing
  )
}

let navigationStackReducer = Reducer<
  NavigationStackState,
  NavigationStackAction,
  NavigationStackEnvironment
> { state, action, environment in
  switch action {
  case .goToABCButtonTapped:
    state.path.append(.init(id: environment.nextId(), element: .screenA(.init())))
    state.path.append(.init(id: environment.nextId(), element: .screenB(.init())))
    state.path.append(.init(id: environment.nextId(), element: .screenC(.init(id: UUID()))))
    return .none

  case .shuffleButtonTapped:
    state.path = NavigationState(path: .init(uniqueElements: state.path.shuffled()))
    return .none

  case .navigation:
    // TODO: shows off how to inspect state in entire stack
    state.total = state.path.reduce(into: 0) { total, route in
      switch route.element {
      case let .screenA(state):
        total += state.count
      case let .screenB(state):
        break
      case let .screenC(state):
        total += state.count
      }
    }

    return .none
  }
}
.navigationDestination(
  screenAReducer.pullback(
    // NB: Using explicit CasePath(...) due to Swift compiler bugs
    state: CasePath(NavigationStackState.Route.screenA),
    action: CasePath(NavigationStackAction.Route.screenA),
    environment: { $0 }
  ),
  screenBReducer.pullback(
    state: CasePath(NavigationStackState.Route.screenB),
    action: CasePath(NavigationStackAction.Route.screenB),
    environment: { $0 }
  ),
  screenCReducer.pullback(
    state: CasePath(NavigationStackState.Route.screenC),
    action: CasePath(NavigationStackAction.Route.screenC),
    environment: { $0 }
  )
)
.debug()
struct NavigationStackView: View {
  let store: Store<NavigationStackState, NavigationStackAction>

  var body: some View {
    ZStack(alignment: .bottom) {
      NavigationStackStore(store: self.store) {
        Form {
          Section { Text(readMe) }

          Section{
            NavigationLink(route: NavigationStackState.Route.screenA(.init())) {
              Text("Go to screen A")
            }
            NavigationLink(route: NavigationStackState.Route.screenB(.init())) {
              Text("Go to screen B")
            }
            NavigationLink(route: NavigationStackState.Route.screenC(.init(id: UUID()))) {
              Text("Go to screen C")
            }
          }

          WithViewStore(self.store.stateless) { viewStore in
            Section {
              Button("Go to A → B → C") {
                viewStore.send(.goToABCButtonTapped)
              }
            }
          }
        }
        .navigationDestination(store: self.store) {
          DestinationStore(
            // NB: Using explicit CasePath(...) due to Swift compiler bugs
            state: CasePath(NavigationStackState.Route.screenA).extract(from:),
            action: NavigationStackAction.Route.screenA,
            content: ScreenAView.init(store:)
          )
          DestinationStore(
            state: CasePath(NavigationStackState.Route.screenB).extract(from:),
            action: NavigationStackAction.Route.screenB,
            content: ScreenBView.init(store:)
          )
          DestinationStore(
            state: CasePath(NavigationStackState.Route.screenC).extract(from:),
            action: NavigationStackAction.Route.screenC,
            content: ScreenCView.init(store:)
          )
        }
        .navigationTitle("Navigation Stack")
      }
      .zIndex(0)

      WithViewStore(
        self.store, //.scope(state: { (total: $0.total, depth: $0.path.count) }),
        removeDuplicates: ==
      ) { viewStore in
        if viewStore.path.count > 0 {
          VStack {
            Text("Total count: \(viewStore.total)")
            Button("Shuffle navigation stack") {
              viewStore.send(.shuffleButtonTapped)
            }
            Button("Pop to root") {
              // TODO: choose style
              viewStore.send(.navigation(.setPath([])))
              viewStore.send(.popToRoot)
              viewStore.send(.navigation(.removeAll))
            }
          }
          .padding()
          .transition(.opacity.animation(.default))
          .background(Color.white)
        }
      }
      .zIndex(1)
    }
  }
}

struct ScreenAState: Codable, Equatable, Hashable {
  var count = 0
  var fact: String?
  var isLoading = false
}
enum ScreenAAction: Equatable {
  case decrementButtonTapped
  case incrementButtonTapped
  case factButtonTapped
  case factResponse(Result<String, FactClient.Error>)
}
let screenAReducer = Reducer<
  ScreenAState,
  ScreenAAction,
  NavigationStackEnvironment
> { state, action, environment in
  switch action {
  case .decrementButtonTapped:
    state.count -= 1
    return .none

  case .incrementButtonTapped:
    state.count += 1
    return .none

  case .factButtonTapped:
    state.isLoading = true
    return environment.fact.fetch(state.count)
      .receive(on: environment.mainQueue)
      .catchToEffect(ScreenAAction.factResponse)

  case let .factResponse(.success(fact)):
    state.isLoading = false
    state.fact = fact
    return .none

  case .factResponse(.failure):
    state.isLoading = false
    state.fact = nil
    // TODO: error handling
    return .none
  }
}
struct ScreenAView: View {
  let store: Store<ScreenAState, ScreenAAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Section {
          HStack {
            Text("\(viewStore.count)")
            Spacer()
            Button("-") { viewStore.send(.decrementButtonTapped) }
            Button("+") { viewStore.send(.incrementButtonTapped) }
          }
          .buttonStyle(.borderless)

          Button(action: { viewStore.send(.factButtonTapped) }) {
            HStack {
              Text("Get fact")
              Spacer()
              if viewStore.isLoading {
                ProgressView()
              }
            }
          }

          if let fact = viewStore.fact {
            Text(fact)
          }
        }

        Section {
          NavigationLink(route: NavigationStackState.Route.screenA(.init(count: viewStore.count))) {
            Text("Go to screen A")
          }
          NavigationLink(route: NavigationStackState.Route.screenB(.init())) {
            Text("Go to screen B")
          }
          NavigationLink(route: NavigationStackState.Route.screenC(.init(id: UUID()))) {
            Text("Go to screen C")
          }
        }
      }
    }
    .navigationTitle("Screen A")
  }
}

struct ScreenBState: Codable, Equatable, Hashable {
}
enum ScreenBAction: Equatable {}
let screenBReducer = Reducer<ScreenBState, ScreenBAction, Void> { state, action, _ in
  switch action {
  }
}
struct ScreenBView: View {
  let store: Store<ScreenBState, ScreenBAction>
  var body: some View {
    Form {

    }
    .navigationTitle("Screen B")
  }
}

struct ScreenCState: Codable, Equatable, Hashable {
  // TODO: this should be pulled from @Dependency once we have it
  let id: UUID
  var count = 0
}
enum ScreenCAction: Equatable {
  case startButtonTapped
  case stopButtonTapped
  case timerTick
}
let screenCReducer = Reducer<
  ScreenCState,
  ScreenCAction,
  NavigationStackEnvironment
> { state, action, environment in
  struct TimerId: Hashable { var id: AnyHashable }

  switch action {
  case .startButtonTapped:
    return Effect.timer(id: TimerId(id: state.id), every: 1, on: environment.mainQueue)
      .map { _ in .timerTick }

  case .stopButtonTapped:
    return .cancel(id: TimerId.self)

  case .timerTick:
    state.count += 1
    return .none
  }
}
struct ScreenCView: View {
  let store: Store<ScreenCState, ScreenCAction>
  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Section {
          Text("\(viewStore.count)")
          Button("Start timer") { viewStore.send(.startButtonTapped) }
          Button("Stop timer") { viewStore.send(.stopButtonTapped) }
        }

        Section {
          NavigationLink(route: NavigationStackState.Route.screenA(.init(count: viewStore.count))) {
            Text("Go to screen A")
          }
          NavigationLink(route: NavigationStackState.Route.screenB(.init())) {
            Text("Go to screen B")
          }
          NavigationLink(route: NavigationStackState.Route.screenC(.init(id: UUID()))) {
            Text("Go to screen C")
          }
        }
      }
      .navigationTitle("Screen C")
    }
  }
}

struct NavigationStack_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStackView(
      store: .init(
        initialState: .init(
          path: [
//            0: .screenA(.init()),
//            1: .screenA(.init(count: 100)),
          ]
        ),
        reducer: navigationStackReducer,
        environment: .live
      )
    )
  }
}

extension Int {
  static var incrementing: () -> Int {
    var count = 0
    return {
      defer { count += 1 }
      return count
    }
  }
}
