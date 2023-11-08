import ComposableArchitecture
import SwiftUI

@Reducer
private struct BindingLocalTestCase {
  struct State: Equatable {
    @PresentationState var fullScreenCover: Child.State?
    @PresentationState var navigationDestination: Child.State?
    var path = StackState<Child.State>()
    @PresentationState var popover: Child.State?
    @PresentationState var sheet: Child.State?
  }
  enum Action {
    case fullScreenCover(PresentationAction<Child.Action>)
    case fullScreenCoverButtonTapped
    case navigationDestination(PresentationAction<Child.Action>)
    case navigationDestinationButtonTapped
    case path(StackAction<Child.State, Child.Action>)
    case popover(PresentationAction<Child.Action>)
    case popoverButtonTapped
    case sheet(PresentationAction<Child.Action>)
    case sheetButtonTapped
  }
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .fullScreenCover:
        return .none
      case .fullScreenCoverButtonTapped:
        state.fullScreenCover = Child.State()
        return .none
      case .navigationDestination:
        return .none
      case .navigationDestinationButtonTapped:
        state.navigationDestination = Child.State()
        return .none
      case .path:
        return .none
      case .popover:
        return .none
      case .popoverButtonTapped:
        state.popover = Child.State()
        return .none
      case .sheet:
        return .none
      case .sheetButtonTapped:
        state.sheet = Child.State()
        return .none
      }
    }
    .forEach(\.path, action: \.path) {
      Child()
    }
    .ifLet(\.$fullScreenCover, action: \.fullScreenCover) {
      Child()
    }
    .ifLet(\.$navigationDestination, action: \.navigationDestination) {
      Child()
    }
    .ifLet(\.$popover, action: \.popover) {
      Child()
    }
    .ifLet(\.$sheet, action: \.sheet) {
      Child()
    }
  }
}

@Reducer
private struct Child {
  struct State: Equatable {
    @BindingState var sendOnDisappear = false
    @BindingState var text = ""
  }
  enum Action: BindableAction {
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
    NavigationStackStore(self.store.scope(state: \.path, action: { .path($0) })) {
      VStack {
        Button("Full-screen-cover") {
          self.store.send(.fullScreenCoverButtonTapped)
        }
        Button("Navigation destination") {
          self.store.send(.navigationDestinationButtonTapped)
        }
        NavigationLink("Path", state: Child.State())
        Button("Popover") {
          self.store.send(.popoverButtonTapped)
        }
        Button("Sheet") {
          self.store.send(.sheetButtonTapped)
        }
      }
      .fullScreenCover(
        store: self.store.scope(state: \.$fullScreenCover, action: { .fullScreenCover($0) })
      ) { store in
        ChildView(store: store)
      }
      .navigationDestination(
        store: self.store.scope(
          state: \.$navigationDestination, action: { .navigationDestination($0) }
        )
      ) { store in
        ChildView(store: store)
      }
      .popover(store: self.store.scope(state: \.$popover, action: { .popover($0) })) { store in
        ChildView(store: store)
      }
      .sheet(store: self.store.scope(state: \.$sheet, action: { .sheet($0) })) { store in
        ChildView(store: store)
      }
    } destination: { store in
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
        TextField("Text", text: viewStore.$text)
        Button(viewStore.sendOnDisappear ? "Don't send onDisappear" : "Send onDisappear") {
          viewStore.$sendOnDisappear.wrappedValue.toggle()
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
