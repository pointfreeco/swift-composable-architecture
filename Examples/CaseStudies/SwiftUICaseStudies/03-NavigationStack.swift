import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates how to use NavigationStack with Composable Architecture applications.
  """

struct NavigationDemo: ReducerProtocol {
  struct State: Equatable {
    var navigation = StackState<Path.State>()
  }

  enum Action: Equatable {
    case goBackToScreen(Int)
    case goToABCButtonTapped
    case navigation(StackAction<Path.State, Path.Action>)
    case popToRoot
  }

  var body: some ReducerProtocol<State, Action> {
    Reduce<State, Action> { state, action in
      switch action {
      case let .goBackToScreen(n):
        state.navigation.removeLast(n)
        return .none

      case .goToABCButtonTapped:
        state.navigation.append(.screenA(.init()))
        state.navigation.append(.screenB(.init()))
        state.navigation.append(.screenC(.init()))
        return .none

      case let .navigation(action):
        switch action {
        case .element(id: _, action: .screenB(.screenAButtonTapped)):
          state.navigation.append(.screenA(.init()))
          return .none

        case .element(id: _, action: .screenB(.screenBButtonTapped)):
          state.navigation.append(.screenB(.init()))
          return .none

        case .element(id: _, action: .screenB(.screenCButtonTapped)):
          state.navigation.append(.screenC(.init()))
          return .none

        default:
          return .none
        }

      case .popToRoot:
        state.navigation.removeAll()
        return .none
      }
    }
    .forEach(\.navigation, action: /Action.navigation) {
      Path()
    }
  }

  struct Path: ReducerProtocol {
    enum State: Codable, Equatable, Hashable {
      case screenA(ScreenA.State)
      case screenB(ScreenB.State)
      case screenC(ScreenC.State)
    }

    enum Action: Equatable {
      case screenA(ScreenA.Action)
      case screenB(ScreenB.Action)
      case screenC(ScreenC.Action)
    }

    var body: some ReducerProtocol<State, Action> {
      Scope(state: /State.screenA, action: /Action.screenA) {
        ScreenA()
      }
      Scope(state: /State.screenB, action: /Action.screenB) {
        ScreenB()
      }
      Scope(state: /State.screenC, action: /Action.screenC) {
        ScreenC()
      }
    }
  }
}

struct NavigationDemoView: View {
  let store: StoreOf<NavigationDemo>

  var body: some View {
    ZStack(alignment: .bottom) {
      NavigationStackStore(
        self.store.scope(state: \.navigation, action: NavigationDemo.Action.navigation)
      ) {
        Form {
          Section { Text(readMe) }

          Section {
            NavigationLink(
              "Go to screen A",
              state: NavigationDemo.Path.State.screenA(.init())
            )
            NavigationLink(
              "Go to screen B",
              state: NavigationDemo.Path.State.screenB(.init())
            )
            NavigationLink(
              "Go to screen C",
              state: NavigationDemo.Path.State.screenC(.init())
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
        .navigationTitle("Root")
      } destination: { state in
        switch state {
        case .screenA:
          CaseLet(
            state: /NavigationDemo.Path.State.screenA,
            action: NavigationDemo.Path.Action.screenA,
            then: ScreenAView.init(store:)
          )
        case .screenB:
          CaseLet(
            state: /NavigationDemo.Path.State.screenB,
            action: NavigationDemo.Path.Action.screenB,
            then: ScreenBView.init(store:)
          )
        case .screenC:
          CaseLet(
            state: /NavigationDemo.Path.State.screenC,
            action: NavigationDemo.Path.Action.screenC,
            then: ScreenCView.init(store:)
          )
        }
      }
      .zIndex(0)

      FloatingMenuView(store: self.store)
        .zIndex(1)
    }
    .navigationTitle("Navigation Stack")
  }
}

// MARK: - Floating menu

struct FloatingMenuView: View {
  let store: StoreOf<NavigationDemo>

  struct ViewState: Equatable {
    var currentStack: [String]
    var total: Int
    init(state: NavigationDemo.State) {
      self.total = 0
      self.currentStack = []
      for element in state.navigation {
        switch element {
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
    WithViewStore(self.store.scope(state: ViewState.init)) { viewStore in
      if viewStore.currentStack.count > 0 {
        VStack(alignment: .leading) {
          Text("Total count: \(viewStore.total)")
          Button("Pop to root") {
            viewStore.send(.popToRoot, animation: .default)
          }

          Menu {
            ForEach(Array(viewStore.currentStack.enumerated()), id: \.offset) { offset, screen in
              Button("\(viewStore.currentStack.count - offset).) \(screen)") {
                viewStore.send(.goBackToScreen(offset))
              }
              .disabled(offset == 0)
            }
            Button("Root") {
              viewStore.send(.popToRoot, animation: .default)
            }
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

  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
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
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      Form {
        Section {
          HStack {
            Text("\(viewStore.count)")
            Spacer()
            Button {
              viewStore.send(.decrementButtonTapped)
            } label: {
              Image(systemName: "minus")
            }
            Button {
              viewStore.send(.incrementButtonTapped)
            } label: {
              Image(systemName: "plus")
            }
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
            state: NavigationDemo.Path.State.screenA(.init(count: viewStore.count))
          )
          NavigationLink(
            "Go to screen B",
            state: NavigationDemo.Path.State.screenB(.init())
          )
          NavigationLink(
            "Go to screen C",
            state: NavigationDemo.Path.State.screenC(.init())
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
    case dismissButtonTapped
    case screenAButtonTapped
    case screenBButtonTapped
    case screenCButtonTapped
  }

  @Dependency(\.dismiss) var dismiss

  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    case .dismissButtonTapped:
      return .fireAndForget {
        await self.dismiss()
      }
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
        Button("Dismiss") {
          viewStore.send(.dismissButtonTapped)
        }
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
  enum TimerID {}

  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {

    switch action {
    case .startButtonTapped:
      state.isTimerRunning = true
      return .run { send in
        for await _ in self.mainQueue.timer(interval: 1) {
          await send(.timerTick)
        }
      }
      .cancellable(id: TimerID.self)
      .concatenate(with: .init(value: .stopButtonTapped))

    case .stopButtonTapped:
      state.isTimerRunning = false
      return .cancel(id: TimerID.self)

    case .timerTick:
      state.count += 1
      return .none
    }
  }
}

struct ScreenCView: View {
  let store: StoreOf<ScreenC>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
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
            state: NavigationDemo.Path.State.screenA(.init(count: viewStore.count))
          )
          NavigationLink(
            "Go to screen B",
            state: NavigationDemo.Path.State.screenB(.init())
          )
          NavigationLink(
            "Go to screen C",
            state: NavigationDemo.Path.State.screenC(.init())
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
      store: Store(
        initialState: NavigationDemo.State(),
        reducer: NavigationDemo()
      )
    )
  }
}
