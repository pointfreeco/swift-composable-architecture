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
  case navigation(NavigationAction<NavigationStackState.Route, Route>)

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
          Section {
            Text(readMe)
          }

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

      WithViewStore(
        self.store.scope(state: { (total: $0.total, depth: $0.path.count) }),
        removeDuplicates: ==
      ) { viewStore in
        VStack {
          Text("Total count: \(viewStore.total)")
          if viewStore.depth > 0 {
            Button("Go home") {
              // TODO: choose style
              viewStore.send(.navigation(.setPath([])))
              viewStore.send(.popToRoot)
              viewStore.send(.navigation(.removeAll))
            }
          }
        }
        .animation(.default, value: viewStore.depth)
        .background(Color.white)
      }
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
    Text("Screen B")
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
    }
  }
}



//
//struct LoadThenNavigateListState: Equatable {
//  var rows: IdentifiedArrayOf<Row> = [
//    .init(count: 1, id: UUID()),
//    .init(count: 42, id: UUID()),
//    .init(count: 100, id: UUID()),
//  ]
//  var selection: Identified<Row.ID, CounterState>?
//
//  struct Row: Equatable, Identifiable {
//    var count: Int
//    let id: UUID
//    var isActivityIndicatorVisible = false
//  }
//}
//
//enum LoadThenNavigateListAction: Equatable {
//  case counter(CounterAction)
//  case onDisappear
//  case setNavigation(selection: UUID?)
//  case setNavigationSelectionDelayCompleted(UUID)
//}
//
//struct LoadThenNavigateListEnvironment {
//  var mainQueue: AnySchedulerOf<DispatchQueue>
//}
//
//let loadThenNavigateListReducer =
//counterReducer
//  .pullback(
//    state: \Identified.value,
//    action: .self,
//    environment: { $0 }
//  )
//  .optional()
//  .pullback(
//    state: \LoadThenNavigateListState.selection,
//    action: /LoadThenNavigateListAction.counter,
//    environment: { _ in CounterEnvironment() }
//  )
//  .combined(
//    with: Reducer<
//    LoadThenNavigateListState, LoadThenNavigateListAction, LoadThenNavigateListEnvironment
//    > { state, action, environment in
//
//      enum CancelId {}
//
//      switch action {
//      case .counter:
//        return .none
//
//      case .onDisappear:
//        return .cancel(id: CancelId.self)
//
//      case let .setNavigation(selection: .some(navigatedId)):
//        for row in state.rows {
//          state.rows[id: row.id]?.isActivityIndicatorVisible = row.id == navigatedId
//        }
//
//        return Effect(value: .setNavigationSelectionDelayCompleted(navigatedId))
//          .delay(for: 1, scheduler: environment.mainQueue)
//          .eraseToEffect()
//          .cancellable(id: CancelId.self, cancelInFlight: true)
//
//      case .setNavigation(selection: .none):
//        if let selection = state.selection {
//          state.rows[id: selection.id]?.count = selection.count
//        }
//        state.selection = nil
//        return .cancel(id: CancelId.self)
//
//      case let .setNavigationSelectionDelayCompleted(id):
//        state.rows[id: id]?.isActivityIndicatorVisible = false
//        state.selection = Identified(
//          CounterState(count: state.rows[id: id]?.count ?? 0),
//          id: id
//        )
//        return .none
//      }
//    }
//  )
//
//struct LoadThenNavigateListView: View {
//  let store: Store<LoadThenNavigateListState, LoadThenNavigateListAction>
//
//  var body: some View {
//    WithViewStore(self.store) { viewStore in
//      Form {
//        Section(header: Text(readMe)) {
//          ForEach(viewStore.rows) { row in
//            NavigationLink(
//              destination: IfLetStore(
//                self.store.scope(
//                  state: \.selection?.value,
//                  action: LoadThenNavigateListAction.counter
//                ),
//                then: CounterView.init(store:)
//              ),
//              tag: row.id,
//              selection: viewStore.binding(
//                get: \.selection?.id,
//                send: LoadThenNavigateListAction.setNavigation(selection:)
//              )
//            ) {
//              HStack {
//                Text("Load optional counter that starts from \(row.count)")
//                if row.isActivityIndicatorVisible {
//                  Spacer()
//                  ProgressView()
//                }
//              }
//            }
//          }
//        }
//      }
//      .navigationBarTitle("Load then navigate")
//      .onDisappear { viewStore.send(.onDisappear) }
//    }
//  }
//}
//
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
