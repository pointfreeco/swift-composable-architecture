import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates how to use NavigationStack with Composable Architecture applications.
  """

struct NavigationDemo: ReducerProtocol {
  struct State: Equatable, NavigableState {
    var path = NavigationState<DestinationState>()
  }

  enum Action: Equatable, NavigableAction {
    case goBackToScreen(Int)
    case goToABCButtonTapped
    case navigation(NavigationAction<DestinationState, DestinationAction>)
    case shuffleButtonTapped
    case cancelTimersButtonTapped
  }

  enum DestinationState: Codable, Equatable, Hashable {
    case screenA(ScreenA.State)
    case screenB(ScreenB.State)
    case screenC(ScreenC.State)
  }

  enum DestinationAction: Equatable {
    case screenA(ScreenA.Action)
    case screenB(ScreenB.Action)
    case screenC(ScreenC.Action)
  }

  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case let .goBackToScreen(n):
        state.path.removeLast(n)
        return .none

      case .goToABCButtonTapped:
        state.path.append(.screenA(.init()))
        state.path.append(.screenB(.init()))
        state.path.append(.screenC(.init()))
        return .none

      case .shuffleButtonTapped:
        state.path.shuffle()
        return .none

      case .navigation(.element(id: _, .screenB(.screenAButtonTapped))):
        state.path.append(.screenA(.init()))
        return .none

      case .navigation(.element(id: _, .screenB(.screenBButtonTapped))):
        state.path.append(.screenB(.init()))
        return .none

      case .navigation(.element(id: _, .screenB(.screenCButtonTapped))):
        state.path.append(.screenC(.init()))
        return .none

      case .navigation:
        return .none

      case .cancelTimersButtonTapped:
        return .merge(state.path.compactMap { state in
          switch state.element {
          case .screenA, .screenB:
            return nil

          case .screenC:
            return .cancel(id: state.id)
          }
        })
      }
    }
    .navigationDestination(
      state: /DestinationState.screenA,
      action: /DestinationAction.screenA
    ) {
      ScreenA()
    }
    .navigationDestination(
      state: /DestinationState.screenB,
      action: /DestinationAction.screenB
    ) {
      ScreenB()
    }
    .navigationDestination(
      state: /DestinationState.screenC,
      action: /DestinationAction.screenC
    ) {
      ScreenC()
    }
  }
}

struct NavigationDemoView: View {
  let store: StoreOf<NavigationDemo>

  var body: some View {
    ZStack(alignment: .bottom) {
      NavigationStackStore(store: self.store) {
        Form {
          Section { Text(readMe) }

          Section {
            NavigationLink(
              "Go to screen A",
              state: NavigationDemo.DestinationState.screenA(.init())
            )
            NavigationLink(
              "Go to screen B",
              state: NavigationDemo.DestinationState.screenB(.init())
            )
            NavigationLink(
              "Go to screen C",
              state: NavigationDemo.DestinationState.screenC(.init())
            )
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
            state: /NavigationDemo.DestinationState.screenA,
            action: NavigationDemo.DestinationAction.screenA,
            content: ScreenAView.init(store:)
          )
          DestinationStore(
            state: /NavigationDemo.DestinationState.screenB,
            action: NavigationDemo.DestinationAction.screenB,
            content: ScreenBView.init(store:)
          )
          DestinationStore(
            state: /NavigationDemo.DestinationState.screenC,
            action: NavigationDemo.DestinationAction.screenC,
            content: ScreenCView.init(store:)
          )
        }
        .navigationTitle("Navigation Stack")
      }
      .zIndex(0)

      FloatingMenuView(store: self.store)
        .zIndex(1)
    }
  }
}

struct FloatingMenuView: View {
  let store: StoreOf<NavigationDemo>

  struct State: Equatable {
    var currentStack: [String]
    var total: Int
    init(state: NavigationDemo.State) {
      self.total = 0
      self.currentStack = []
      for route in state.path {
        switch route.element {
        case let .screenA(screenAState):
          self.total += screenAState.count
          self.currentStack.insert("Screen A", at: 0)
        case .screenB:
          self.currentStack.insert("Screen B", at: 0)
        case let .screenC(screenBState):
          self.total += screenBState.count
          self.currentStack.insert("Screen C", at: 0)
        }
      }
    }
  }

  var body: some View {
    WithViewStore(self.store.scope(state: State.init)) { viewStore in
      if viewStore.currentStack.count > 0 {
        VStack(alignment: .leading) {
          Text("Total count: \(viewStore.total)")
          Button("Shuffle navigation stack") {
            viewStore.send(.shuffleButtonTapped)
          }
          Button("Pop to root") {
            // TODO: choose style
            viewStore.send(.popToRoot)
            // viewStore.send(.navigation(.setPath([])))
            // viewStore.send(.navigation(.removeAll))
          }
          Button("Cancel timers") {
            viewStore.send(.cancelTimersButtonTapped)
          }

          Menu {
            ForEach(Array(viewStore.currentStack.enumerated()), id: \.offset) { offset, screen in
              Button("\(viewStore.currentStack.count - offset).) \(screen)") {
                viewStore.send(.goBackToScreen(offset))
              }
              .disabled(offset == 0)
            }
            Button("Root") { viewStore.send(.popToRoot) }
          } label: {
            Text("Current stack")
          }
        }
        .padding()
        .background(Color.white)
        .padding(.bottom, 1)
        .transition(.opacity.animation(.default))
      }
    }
    .debug()
  }
}

// MARK: - Screen A

struct ScreenA: ReducerProtocol {
  struct State: Codable, Equatable, Hashable {
    var count = 0
    var fact: String?
    var isLoading = false
  }

  enum Action: Equatable {
    case decrementButtonTapped
    case incrementButtonTapped
    case factButtonTapped
    case factResponse(TaskResult<String>)
  }

  @Dependency(\.factClient) var factClient

  func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    switch action {
    case .decrementButtonTapped:
      state.count -= 1
      return .none

    case .incrementButtonTapped:
      state.count += 1
      return .none

    case .factButtonTapped:
      state.isLoading = true
      return .task { [count = state.count] in
        await .factResponse(.init { try await self.factClient.fetch(count) })
      }

    case let .factResponse(.success(fact)):
      state.isLoading = false
      state.fact = fact
      return .none

    case .factResponse(.failure):
      state.isLoading = false
      state.fact = nil
      // TODO: Error handling?
      return .none
    }
  }
}

struct ScreenAView: View {
  let store: StoreOf<ScreenA>

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
          NavigationLink(
            "Go to screen A",
            state: NavigationDemo.DestinationState.screenA(.init(count: viewStore.count))
          )
          NavigationLink(
            "Go to screen B",
            state: NavigationDemo.DestinationState.screenB(.init())
          )
          NavigationLink(
            "Go to screen C",
            state: NavigationDemo.DestinationState.screenC(.init())
          )
        }
      }
    }
    .navigationTitle("Screen A")
  }
}

// MARK: - Screen B

struct ScreenB: ReducerProtocol {
  struct State: Codable, Equatable, Hashable {}

  enum Action: Equatable {
    case screenAButtonTapped
    case screenBButtonTapped
    case screenCButtonTapped
  }

  func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    switch action {
    case .screenAButtonTapped:
      return .none
    case .screenBButtonTapped:
      return .none
    case .screenCButtonTapped:
      return .none
    }
  }
}

struct ScreenBView: View {
  let store: StoreOf<ScreenB>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Button("Decoupled navigation to screen A") {
          viewStore.send(.screenAButtonTapped)
        }
        Button("Decoupled navigation to screen B") {
          viewStore.send(.screenBButtonTapped)
        }
        Button("Decoupled navigation to screen C") {
          viewStore.send(.screenCButtonTapped)
        }
      }
      .navigationTitle("Screen B")
    }
  }
}

// MARK: - Screen C

struct ScreenC: ReducerProtocol {
  struct State: Codable, Equatable, Hashable {
    var count = 0
    var isTimerRunning = false
  }

  enum Action: Equatable {
    case startButtonTapped
    case stopButtonTapped
    case timerTick
  }

  @Dependency(\.mainQueue) var mainQueue

  func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    enum TimerId {}

    switch action {
    case .startButtonTapped:
      state.isTimerRunning = true
      return .run { send in
        for await _ in self.mainQueue.timer(interval: 1) {
          await send(.timerTick)
        }
      }

    case .stopButtonTapped:
      state.isTimerRunning = false
      return .cancel(id: TimerId.self)

    case .timerTick:
      state.count += 1
      return .none
    }
  }
}

struct ScreenCView: View {
  let store: StoreOf<ScreenC>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Section {
          Text("\(viewStore.count)")
          if viewStore.isTimerRunning {
            Button("Stop timer") { viewStore.send(.stopButtonTapped) }
          } else {
            Button("Start timer") { viewStore.send(.startButtonTapped) }
          }
        }

        Section {
          NavigationLink(
            "Go to screen A",
            state: NavigationDemo.DestinationState.screenA(.init(count: viewStore.count))
          )
          NavigationLink(
            "Go to screen B",
            state: NavigationDemo.DestinationState.screenB(.init())
          )
          NavigationLink(
            "Go to screen C",
            state: NavigationDemo.DestinationState.screenC(.init())
          )
        }
      }
      .navigationTitle("Screen C")
    }
  }
}

// MARK: - Previews

struct NavigationStack_Previews: PreviewProvider {
  static var previews: some View {
    NavigationDemoView(
      store: .init(
        initialState: .init(),
        reducer: NavigationDemo()
      )
    )
  }
}
