import ComposableArchitecture
import SwiftUI

private struct DestinationView: View {
  let store: StoreOf<EmptyReducer<Int, Never>>
  var body: some View {
    Text("Destination")
  }
}

@Reducer
private struct ChildFeature {
  struct State: Equatable {
    @PresentationState var alert: AlertState<Action.Alert>?
    @PresentationState var navigationDestination: Int?
    var count = 0
    var hasAppeared = false
  }
  enum Action {
    case alert(PresentationAction<Alert>)
    case navigationDestination(PresentationAction<Never>)
    case decrementButtonTapped
    case dismissButtonTapped
    case incrementButtonTapped
    case onAppear
    case popToRootButtonTapped
    case recreateStack
    case response(Int)
    case runButtonTapped
    case navigationDestinationButtonTapped
    case showAlertButtonTapped
    enum Alert {
      case pop
    }
  }
  @Dependency(\.dismiss) var dismiss
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .alert:
        return .none
      case .navigationDestination:
        return .none
      case .decrementButtonTapped:
        state.count -= 1
        return .none
      case .dismissButtonTapped:
        return .run { _ in await self.dismiss() }
      case .incrementButtonTapped:
        state.count += 1
        return .none
      case .onAppear:
        state.hasAppeared = true
        return .none
      case .popToRootButtonTapped:
        return .none
      case .recreateStack:
        return .none
      case let .response(value):
        state.count = value
        return .none
      case .runButtonTapped:
        return .run { [count = state.count] send in
          try await Task.sleep(for: .seconds(2))
          await send(.response(count + 1))
        }
      case .navigationDestinationButtonTapped:
        state.navigationDestination = 1
        return .none
      case .showAlertButtonTapped:
        state.alert = AlertState {
          TextState("What do you want to do?")
        } actions: {
          ButtonState(action: .pop) {
            TextState("Parent pops feature")
          }
        }
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
    .ifLet(\.$navigationDestination, action: \.navigationDestination) {
      EmptyReducer()
    }
  }
}

private struct ChildView: View {
  let store: StoreOf<ChildFeature>
  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      Form {
        if viewStore.hasAppeared {
          Text("Has appeared")
        }

        Section {
          Text("\(viewStore.count)")
          Button("Decrement") { viewStore.send(.decrementButtonTapped) }
          Button("Increment") { viewStore.send(.incrementButtonTapped) }
        }
        Button("Run effect") {
          viewStore.send(.runButtonTapped)
        }
        Button("Dismiss") {
          viewStore.send(.dismissButtonTapped)
        }
        Button("Pop to root") {
          viewStore.send(.popToRootButtonTapped)
        }
        Button("Recreate stack") {
          viewStore.send(.recreateStack)
        }
        Button("Show alert") {
          viewStore.send(.showAlertButtonTapped)
        }
        Button("Open navigation destination") {
          viewStore.send(.navigationDestinationButtonTapped)
        }
        NavigationLink(state: ChildFeature.State(count: viewStore.count)) {
          Text("Go to counter: \(viewStore.count)")
        }
      }
      .onAppear {
        print("onAppear")
        viewStore.send(.onAppear)
      }
      .alert(store: self.store.scope(state: \.$alert, action: \.alert))
      .navigationDestination(
        store: self.store.scope(state: \.$navigationDestination, action: \.navigationDestination)
      ) {
        DestinationView(store: $0)
      }
    }
  }
}

@Reducer
private struct NavigationStackTestCase {
  struct State: Equatable {
    var children = StackState<ChildFeature.State>()
    var childResponse: Int?
  }
  enum Action {
    case child(StackActionOf<ChildFeature>)
  }
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .child(.element(id: _, action: .response(value))):
        state.childResponse = value
        return .none
      case .child(.element(id: _, action: .recreateStack)):
        state.children = StackState(state.children.map { _ in ChildFeature.State() })
        return .none
      case .child(.element(id: _, action: .popToRootButtonTapped)):
        state.children = StackState()
        return .none
      case let .child(.element(id: id, action: .alert(.presented(.pop)))):
        state.children.pop(from: id)
        return .none
      case .child:
        return .none
      }
    }
    .forEach(\.children, action: \.child) { ChildFeature() }
  }
}

struct NavigationStackTestCaseView: View {
  private let store: StoreOf<NavigationStackTestCase>
  @StateObject private var viewStore: ViewStoreOf<NavigationStackTestCase>

  init() {
    let store = Store(initialState: NavigationStackTestCase.State()) {
      NavigationStackTestCase()
        ._printChanges()
    }
    self.store = store
    self._viewStore = StateObject(
      wrappedValue: ViewStore(store, observe: { $0 })
    )
  }

  var body: some View {
    NavigationStackStore(self.store.scope(state: \.children, action: \.child)) {
      WithViewStore(self.store, observe: \.childResponse) { viewStore in
        Form {
          if let childResponse = viewStore.state {
            Text("Child response: \(childResponse)")
          }

          NavigationLink(state: ChildFeature.State()) {
            Text("Go to counter")
          }
        }
      }
      .navigationTitle("Root")
    } destination: {
      ChildView(store: $0)
    }
  }
}
