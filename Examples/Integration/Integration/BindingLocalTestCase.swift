import ComposableArchitecture
import SwiftUI

private struct BindingLocalTestCase: Reducer {
  struct State: Equatable {
    @PresentationState var child: Child.State?
  }
  enum Action: Equatable {
    case child(PresentationAction<Child.Action>)
    case childButtonTapped
  }
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .child:
        return .none
      case .childButtonTapped:
        state.child = Child.State()
        return .none
      }
    }
    .ifLet(\.$child, action: /Action.child) {
      Child()
    }
  }
}

private struct Child: Reducer {
  struct State: Equatable {
    @BindingState var sendOnDisappear = false
    @BindingState var text = ""
  }
  enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
    case onDisappear
  }
  var body: some ReducerOf<Self> {
    BindingReducer()
  }
}

struct BindingLocalTestCaseView: View {
  private let store = Store(initialState: BindingLocalTestCase.State()) {
    BindingLocalTestCase()
  }

  var body: some View {
    Button("Child") {
      ViewStore(self.store.stateless).send(.childButtonTapped)
    }
    .sheet(store: self.store.scope(state: \.$child, action: { .child($0) })) { store in
      ChildView(store: store)
    }
  }
}

private struct ChildView: View {
  let store: StoreOf<Child>
  @Environment(\.dismiss) var dismiss

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      Form {
        Button("Dismiss") {
          self.dismiss()
        }
        TextField("Text", text: viewStore.binding(\.$text))
        Button(viewStore.sendOnDisappear ? "Don't send onDisappear" : "Send onDisappear") {
          viewStore.binding(\.$sendOnDisappear).wrappedValue.toggle()
        }
      }
      .onDisappear {
        if viewStore.sendOnDisappear {
          viewStore.send(.onDisappear)
        }
      }
    }
  }
}
