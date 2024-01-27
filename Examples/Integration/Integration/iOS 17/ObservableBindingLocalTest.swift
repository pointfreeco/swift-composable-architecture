import ComposableArchitecture
import SwiftUI

@Reducer
private struct ObservableBindingLocalTestCase {
  @ObservableState
  struct State: Equatable {
    @Presents var fullScreenCover: Child.State?
    @Presents var navigationDestination: Child.State?
    var path = StackState<Child.State>()
    @Presents var popover: Child.State?
    @Presents var sheet: Child.State?
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
  @ObservableState
  struct State: Equatable {
    var sendOnDisappear = false
    var text = ""
  }
  enum Action: BindableAction {
    case binding(BindingAction<State>)
    case onDisappear
  }
  var body: some ReducerOf<Self> {
    BindingReducer()
  }
}

struct ObservableBindingLocalTestCaseView: View {
  @State fileprivate var store = Store(initialState: ObservableBindingLocalTestCase.State()) {
    ObservableBindingLocalTestCase()
  }

  var body: some View {
    WithPerceptionTracking {
      NavigationStack(path: self.$store.scope(state: \.path, action: \.path)) {
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
          item: self.$store.scope(state: \.fullScreenCover, action: \.fullScreenCover)
        ) { store in
          ChildView(store: store)
        }
        .navigationDestination(
          store: self.store.scope(state: \.$navigationDestination, action: \.navigationDestination)
        ) { store in
          ChildView(store: store)
        }
        .popover(item: self.$store.scope(state: \.popover, action: \.popover)) { store in
          ChildView(store: store)
        }
        .sheet(item: self.$store.scope(state: \.sheet, action: \.sheet)) { store in
          ChildView(store: store)
        }
      } destination: { store in
        ChildView(store: store)
      }
    }
  }
}

private struct ChildView: View {
  @State fileprivate var store: StoreOf<Child>
  @Environment(\.dismiss) var dismiss

  var body: some View {
    Form {
      Button("Dismiss") {
        self.dismiss()
      }
      TextField("Text", text: self.$store.text)
      Button(self.store.sendOnDisappear ? "Don't send onDisappear" : "Send onDisappear") {
        self.store.sendOnDisappear.toggle()
      }
    }
    .onDisappear {
      if self.store.sendOnDisappear {
        self.store.send(.onDisappear)
      }
    }
  }
}
