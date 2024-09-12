import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates how to use `NavigationStack` with Composable Architecture applications.
  """

@Reducer
struct NavigationDemo {
  @Reducer
  enum Path {
    case screenA(ScreenA)
    case screenB(ScreenB)
    case screenC(ScreenC)
  }

  @ObservableState
  struct State: Equatable {
    var path = StackState<Path.State>()
  }

  enum Action {
    case goBackToScreen(id: StackElementID)
    case goToABCButtonTapped
    case path(StackActionOf<Path>)
    case popToRoot
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case let .goBackToScreen(id):
        state.path.pop(to: id)
        return .none

      case .goToABCButtonTapped:
        state.path.append(.screenA(ScreenA.State()))
        state.path.append(.screenB(ScreenB.State()))
        state.path.append(.screenC(ScreenC.State()))
        return .none

      case let .path(action):
        switch action {
        case .element(id: _, action: .screenB(.screenAButtonTapped)):
          state.path.append(.screenA(ScreenA.State()))
          return .none

        case .element(id: _, action: .screenB(.screenBButtonTapped)):
          state.path.append(.screenB(ScreenB.State()))
          return .none

        case .element(id: _, action: .screenB(.screenCButtonTapped)):
          state.path.append(.screenC(ScreenC.State()))
          return .none

        default:
          return .none
        }

      case .popToRoot:
        state.path.removeAll()
        return .none
      }
    }
    .forEach(\.path, action: \.path)
  }
}
extension NavigationDemo.Path.State: Equatable {}

struct NavigationDemoView: View {
  @Bindable var store: StoreOf<NavigationDemo>

  var body: some View {
    NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
      Form {
        Section { Text(template: readMe) }

        Section {
          NavigationLink(
            "Go to screen A",
            state: NavigationDemo.Path.State.screenA(ScreenA.State())
          )
          NavigationLink(
            "Go to screen B",
            state: NavigationDemo.Path.State.screenB(ScreenB.State())
          )
          NavigationLink(
            "Go to screen C",
            state: NavigationDemo.Path.State.screenC(ScreenC.State())
          )
        }

        Section {
          Button("Go to A → B → C") {
            store.send(.goToABCButtonTapped)
          }
        }
      }
      .navigationTitle("Root")
    } destination: { store in
      switch store.case {
      case let .screenA(store):
        ScreenAView(store: store)
      case let .screenB(store):
        ScreenBView(store: store)
      case let .screenC(store):
        ScreenCView(store: store)
      }
    }
    .safeAreaInset(edge: .bottom) {
      FloatingMenuView(store: store)
    }
    .navigationTitle("Navigation Stack")
  }
}

// MARK: - Floating menu

struct FloatingMenuView: View {
  let store: StoreOf<NavigationDemo>

  struct ViewState: Equatable {
    struct Screen: Equatable, Identifiable {
      let id: StackElementID
      let name: String
    }

    var currentStack: [Screen]
    var total: Int
    init(state: NavigationDemo.State) {
      self.total = 0
      self.currentStack = []
      for (id, element) in zip(state.path.ids, state.path) {
        switch element {
        case let .screenA(screenAState):
          self.total += screenAState.count
          self.currentStack.insert(Screen(id: id, name: "Screen A"), at: 0)
        case .screenB:
          self.currentStack.insert(Screen(id: id, name: "Screen B"), at: 0)
        case let .screenC(screenBState):
          self.total += screenBState.count
          self.currentStack.insert(Screen(id: id, name: "Screen C"), at: 0)
        }
      }
    }
  }

  var body: some View {
    let viewState = ViewState(state: store.state)
    if viewState.currentStack.count > 0 {
      VStack(alignment: .center) {
        Text("Total count: \(viewState.total)")
        Button("Pop to root") {
          store.send(.popToRoot, animation: .default)
        }
        Menu("Current stack") {
          ForEach(viewState.currentStack) { screen in
            Button("\(String(describing: screen.id))) \(screen.name)") {
              store.send(.goBackToScreen(id: screen.id))
            }
            .disabled(screen == viewState.currentStack.first)
          }
          Button("Root") {
            store.send(.popToRoot, animation: .default)
          }
        }
      }
      .padding()
      .background(Color(.systemBackground))
      .padding(.bottom, 1)
      .transition(.opacity.animation(.default))
      .clipped()
      .shadow(color: .black.opacity(0.2), radius: 5, y: 5)
    }
  }
}

// MARK: - Screen A

@Reducer
struct ScreenA {
  @ObservableState
  struct State: Equatable {
    var count = 0
    var fact: String?
    var isLoading = false
  }

  enum Action {
    case decrementButtonTapped
    case dismissButtonTapped
    case incrementButtonTapped
    case factButtonTapped
    case factResponse(Result<String, any Error>)
  }

  @Dependency(\.dismiss) var dismiss
  @Dependency(\.factClient) var factClient

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .decrementButtonTapped:
        state.count -= 1
        return .none

      case .dismissButtonTapped:
        return .run { _ in
          await self.dismiss()
        }

      case .incrementButtonTapped:
        state.count += 1
        return .none

      case .factButtonTapped:
        state.isLoading = true
        return .run { [count = state.count] send in
          await send(.factResponse(Result { try await self.factClient.fetch(count) }))
        }

      case let .factResponse(.success(fact)):
        state.isLoading = false
        state.fact = fact
        return .none

      case .factResponse(.failure):
        state.isLoading = false
        state.fact = nil
        return .none
      }
    }
  }
}

struct ScreenAView: View {
  let store: StoreOf<ScreenA>

  var body: some View {
    Form {
      Text(
        """
        This screen demonstrates a basic feature hosted in a navigation stack.

        You can also have the child feature dismiss itself, which will communicate back to the \
        root stack view to pop the feature off the stack.
        """
      )

      Section {
        HStack {
          Text("\(store.count)")
          Spacer()
          Button {
            store.send(.decrementButtonTapped)
          } label: {
            Image(systemName: "minus")
          }
          Button {
            store.send(.incrementButtonTapped)
          } label: {
            Image(systemName: "plus")
          }
        }
        .buttonStyle(.borderless)

        Button {
          store.send(.factButtonTapped)
        } label: {
          HStack {
            Text("Get fact")
            if store.isLoading {
              Spacer()
              ProgressView()
            }
          }
        }

        if let fact = store.fact {
          Text(fact)
        }
      }

      Section {
        Button("Dismiss") {
          store.send(.dismissButtonTapped)
        }
      }

      Section {
        NavigationLink(
          "Go to screen A",
          state: NavigationDemo.Path.State.screenA(ScreenA.State(count: store.count))
        )
        NavigationLink(
          "Go to screen B",
          state: NavigationDemo.Path.State.screenB(ScreenB.State())
        )
        NavigationLink(
          "Go to screen C",
          state: NavigationDemo.Path.State.screenC(ScreenC.State(count: store.count))
        )
      }
    }
    .navigationTitle("Screen A")
  }
}

// MARK: - Screen B

@Reducer
struct ScreenB {
  @ObservableState
  struct State: Equatable {}

  enum Action {
    case screenAButtonTapped
    case screenBButtonTapped
    case screenCButtonTapped
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
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
}

struct ScreenBView: View {
  let store: StoreOf<ScreenB>

  var body: some View {
    Form {
      Section {
        Text(
          """
          This screen demonstrates how to navigate to other screens without needing to compile \
          any symbols from those screens. You can send an action into the system, and allow the \
          root feature to intercept that action and push the next feature onto the stack.
          """
        )
      }
      Button("Decoupled navigation to screen A") {
        store.send(.screenAButtonTapped)
      }
      Button("Decoupled navigation to screen B") {
        store.send(.screenBButtonTapped)
      }
      Button("Decoupled navigation to screen C") {
        store.send(.screenCButtonTapped)
      }
    }
    .navigationTitle("Screen B")
  }
}

// MARK: - Screen C

@Reducer
struct ScreenC {
  @ObservableState
  struct State: Equatable {
    var count = 0
    var isTimerRunning = false
  }

  enum Action {
    case startButtonTapped
    case stopButtonTapped
    case timerTick
  }

  @Dependency(\.mainQueue) var mainQueue
  enum CancelID { case timer }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .startButtonTapped:
        state.isTimerRunning = true
        return .run { send in
          for await _ in self.mainQueue.timer(interval: 1) {
            await send(.timerTick)
          }
        }
        .cancellable(id: CancelID.timer)
        .concatenate(with: .send(.stopButtonTapped))

      case .stopButtonTapped:
        state.isTimerRunning = false
        return .cancel(id: CancelID.timer)

      case .timerTick:
        state.count += 1
        return .none
      }
    }
  }
}

struct ScreenCView: View {
  let store: StoreOf<ScreenC>

  var body: some View {
    Form {
      Text(
        """
        This screen demonstrates that if you start a long-living effects in a stack, then it \
        will automatically be torn down when the screen is dismissed.
        """
      )
      Section {
        Text("\(store.count)")
        if store.isTimerRunning {
          Button("Stop timer") { store.send(.stopButtonTapped) }
        } else {
          Button("Start timer") { store.send(.startButtonTapped) }
        }
      }

      Section {
        NavigationLink(
          "Go to screen A",
          state: NavigationDemo.Path.State.screenA(ScreenA.State(count: store.count))
        )
        NavigationLink(
          "Go to screen B",
          state: NavigationDemo.Path.State.screenB(ScreenB.State())
        )
        NavigationLink(
          "Go to screen C",
          state: NavigationDemo.Path.State.screenC(ScreenC.State())
        )
      }
    }
    .navigationTitle("Screen C")
  }
}

// MARK: - Previews

#Preview {
  NavigationDemoView(
    store: Store(initialState: NavigationDemo.State()) {
      NavigationDemo()
    }
  )
}
