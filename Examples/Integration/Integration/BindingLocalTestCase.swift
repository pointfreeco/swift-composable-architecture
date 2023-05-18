import ComposableArchitecture
import SwiftUI

private struct BindingLocalTestCase: ReducerProtocol {
  struct State: Equatable {
    @PresentationState var fullScreenCover: Child.State?
    @PresentationState var popover: Child.State?
    @PresentationState var sheet: Child.State?
  }
  enum Action: Equatable {
    case fullScreenCover(PresentationAction<Child.Action>)
    case fullScreenCoverButtonTapped
    case popover(PresentationAction<Child.Action>)
    case popoverButtonTapped
    case sheet(PresentationAction<Child.Action>)
    case sheetButtonTapped
  }
  var body: some ReducerProtocolOf<Self> {
    Reduce { state, action in
      switch action {
      case .fullScreenCover:
        return .none
      case .fullScreenCoverButtonTapped:
        state.fullScreenCover = Child.State()
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
    .ifLet(\.$fullScreenCover, action: /Action.fullScreenCover) {
      Child()
    }
    .ifLet(\.$popover, action: /Action.popover) {
      Child()
    }
    .ifLet(\.$sheet, action: /Action.sheet) {
      Child()
    }
  }
}

private struct Child: ReducerProtocol {
  struct State: Equatable {
    @BindingState var sendOnDisappear = false
    @BindingState var text = ""
  }
  enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
    case onDisappear
  }
  var body: some ReducerProtocolOf<Self> {
    BindingReducer()
  }
}

struct BindingLocalTestCaseView: View {
  private let store = Store(initialState: BindingLocalTestCase.State()) {
    BindingLocalTestCase()
  }

  var body: some View {
    VStack {
      Button("Full-screen-cover") {
        ViewStore(self.store.stateless).send(.fullScreenCoverButtonTapped)
      }
      Button("Popover") {
        ViewStore(self.store.stateless).send(.popoverButtonTapped)
      }
      Button("Sheet") {
        ViewStore(self.store.stateless).send(.sheetButtonTapped)
      }
    }
    .fullScreenCover(
      store: self.store.scope(state: \.$fullScreenCover, action: { .fullScreenCover($0) })
    ) { store in
      ChildView(store: store)
    }
    .popover(store: self.store.scope(state: \.$popover, action: { .popover($0) })) { store in
      ChildView(store: store)
    }
    .sheet(store: self.store.scope(state: \.$sheet, action: { .sheet($0) })) { store in
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
