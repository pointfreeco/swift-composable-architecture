import ComposableArchitecture
import SwiftUI

private struct ChildFeature: ReducerProtocol {
  struct State: Hashable {
    @PresentationState var alert: AlertState<Action.Alert>?
    var count = 0
    var hasAppeared = false
  }
  enum Action {
    case alert(PresentationAction<Alert>)
    case decrementButtonTapped
    case dismissButtonTapped
    case incrementButtonTapped
    case onAppear
    case popToRootButtonTapped
    case recreateStack
    case response(Int)
    case runButtonTapped
    case showAlertButtonTapped
    enum Alert {
      case pop
    }
  }
  @Dependency(\.dismiss) var dismiss
  var body: some ReducerProtocolOf<Self> {
    Reduce { state, action in
      switch action {
      case .alert:
        return .none
      case .decrementButtonTapped:
        state.count -= 1
        return .none
      case .dismissButtonTapped:
        return .fireAndForget { await self.dismiss() }
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
    .ifLet(\.$alert, action: /Action.alert)
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
        NavigationLink(state: ChildFeature.State(count: viewStore.count)) {
          Text("Go to counter: \(viewStore.count)")
        }
      }
      .onAppear {
        print("onAppear")
        viewStore.send(.onAppear)
      }
      .alert(store: self.store.scope(state: \.$alert, action: { .alert($0) }))
    }
  }
}

private struct NavigationStackTestCase: ReducerProtocol {
  struct State: Equatable {
    var children = StackState<ChildFeature.State>()
    var childResponse: Int?
  }
  enum Action {
    case child(StackAction<ChildFeature.State, ChildFeature.Action>)
  }
  var body: some ReducerProtocolOf<Self> {
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
    .forEach(\.children, action: /Action.child) { ChildFeature() }
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
    NavigationStackStore(self.store.scope(state: \.children, action: { .child($0) })) {
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
      .navigationTitle(Text("Root"))
    } destination: {
      ChildView(store: $0)
    }
  }
}
