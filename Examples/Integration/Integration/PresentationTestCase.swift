@preconcurrency import ComposableArchitecture
import SwiftUI

private struct PresentationTestCase: Reducer {
  struct State: Equatable {
    var message = ""
    @PresentationState var destination: Destination.State?
  }
  enum Action: Equatable, Sendable {
    case alertButtonTapped
    case destination(PresentationAction<Destination.Action>)
    case dialogButtonTapped
    case fullScreenCoverButtonTapped
    case navigationDestinationButtonTapped
    case navigationLinkDemoButtonTapped
    case popoverButtonTapped
    case sheetButtonTapped
  }

  struct Destination: Reducer {
    enum State: Equatable {
      case alert(AlertState<AlertAction>)
      case dialog(ConfirmationDialogState<DialogAction>)
      case fullScreenCover(ChildFeature.State)
      case navigationDestination(ChildFeature.State)
      case navigationLinkDemo(NavigationLinkDemoFeature.State)
      case popover(ChildFeature.State)
      case sheet(ChildFeature.State)
    }
    enum Action: Equatable {
      case alert(AlertAction)
      case dialog(DialogAction)
      case fullScreenCover(ChildFeature.Action)
      case navigationDestination(ChildFeature.Action)
      case navigationLinkDemo(NavigationLinkDemoFeature.Action)
      case popover(ChildFeature.Action)
      case sheet(ChildFeature.Action)
    }
    enum AlertAction {
      case ok
      case showDialog
    }
    enum DialogAction {
      case ok
      case showAlert
    }
    var body: some ReducerOf<Self> {
      Scope(state: /State.fullScreenCover, action: /Action.fullScreenCover) {
        ChildFeature()
      }
      Scope(state: /State.navigationDestination, action: /Action.navigationDestination) {
        ChildFeature()
      }
      Scope(state: /State.navigationLinkDemo, action: /Action.navigationLinkDemo) {
        NavigationLinkDemoFeature()
      }
      Scope(state: /State.sheet, action: /Action.sheet) {
        ChildFeature()
      }
      Scope(state: /State.popover, action: /Action.popover) {
        ChildFeature()
      }
    }
  }

  var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .destination(.presented) where state.destination == nil:
        state.message = "Action sent while state nil."
        return .none
      default: return .none
      }
    }
    Reduce<State, Action> { state, action in
      switch action {
      case .alertButtonTapped:
        state.destination = .alert(
          AlertState {
            TextState("Alert open")
          } actions: {
            ButtonState(action: .ok) {
              TextState("OK")
            }
            ButtonState(action: .showDialog) {
              TextState("Show dialog")
            }
            ButtonState(role: .cancel) {
              TextState("Cancel")
            }
          }
        )
        return .none
      case .destination(.presented(.fullScreenCover(.parentSendDismissActionButtonTapped))),
        .destination(.presented(.navigationDestination(.parentSendDismissActionButtonTapped))),
        .destination(.presented(.sheet(.parentSendDismissActionButtonTapped))),
        .destination(.presented(.popover(.parentSendDismissActionButtonTapped))):
        return .send(.destination(.dismiss))
      case .destination(.presented(.alert(.showDialog))):
        state.destination = .dialog(
          ConfirmationDialogState(titleVisibility: .visible) {
            TextState("Hello!")
          } actions: {
          }
        )
        return .none
      case .destination(.presented(.dialog(.showAlert))):
        state.destination = .alert(
          AlertState {
            TextState("Hello!")
          }
        )
        return .none
      case .destination(.dismiss):
        state.message = "Dismiss action sent"
        return .none
      case .destination:
        return .none
      case .dialogButtonTapped:
        state.destination = .dialog(
          ConfirmationDialogState(titleVisibility: .visible) {
            TextState("Dialog open")
          } actions: {
            ButtonState(action: .ok) {
              TextState("OK")
            }
            ButtonState(action: .showAlert) {
              TextState("Show alert")
            }
          }
        )
        return .none
      case .fullScreenCoverButtonTapped:
        state.destination = .fullScreenCover(ChildFeature.State())
        return .none
      case .navigationDestinationButtonTapped:
        state.destination = .navigationDestination(ChildFeature.State())
        return .none
      case .navigationLinkDemoButtonTapped:
        state.destination = .navigationLinkDemo(NavigationLinkDemoFeature.State())
        return .none
      case .popoverButtonTapped:
        state.destination = .popover(ChildFeature.State())
        return .none
      case .sheetButtonTapped:
        state.destination = .sheet(ChildFeature.State())
        return .none
      }
    }
    .ifLet(\.$destination, action: /Action.destination) {
      Destination()
    }
  }
}

private struct ChildFeature: Reducer {
  struct State: Equatable, Identifiable {
    var id = UUID()
    var count = 0
    @BindingState var text = ""
  }
  enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case childDismissButtonTapped
    case incrementButtonTapped
    case parentSendDismissActionButtonTapped
    case resetIdentity
    case response
    case startButtonTapped
  }
  @Dependency(\.dismiss) var dismiss
  var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce<State, Action> { state, action in
      switch action {
      case .binding:
        return .none
      case .childDismissButtonTapped:
        return .fireAndForget { await self.dismiss() }
      case .incrementButtonTapped:
        state.count += 1
        return .none
      case .parentSendDismissActionButtonTapped:
        return .none
      case .resetIdentity:
        state.id = UUID()
        return .none
      case .response:
        state.count = 999
        return .none
      case .startButtonTapped:
        state.count += 1
        return .run { send in
          try await Task.sleep(for: .seconds(2))
          await send(.response)
        }
      }
    }
  }
}

struct PresentationTestCaseView: View {
  private let store: StoreOf<PresentationTestCase>
  @StateObject private var viewStore: ViewStore<String, PresentationTestCase.Action>

  init() {
    let store = Store(
      initialState: PresentationTestCase.State(),
      reducer: PresentationTestCase()._printChanges()
    )
    self.store = store
    self._viewStore = StateObject(
      wrappedValue: ViewStore(store, observe: { $0.message })
    )
  }

  var body: some View {
    Form {
      Section {
        Text(self.viewStore.state)
      }

      Button("Open alert") {
        self.viewStore.send(.alertButtonTapped)
      }
      .alert(
        store: self.store.scope(
          state: \.$destination, action: PresentationTestCase.Action.destination),
        state: /PresentationTestCase.Destination.State.alert,
        action: PresentationTestCase.Destination.Action.alert
      )

      Button("Open dialog") {
        self.viewStore.send(.dialogButtonTapped)
      }
      .confirmationDialog(
        store: self.store.scope(
          state: \.$destination, action: PresentationTestCase.Action.destination),
        state: /PresentationTestCase.Destination.State.dialog,
        action: PresentationTestCase.Destination.Action.dialog
      )

      Button("Open full screen cover") {
        self.viewStore.send(.fullScreenCoverButtonTapped)
      }
      .fullScreenCover(
        store: self.store.scope(
          state: \.$destination, action: PresentationTestCase.Action.destination),
        state: /PresentationTestCase.Destination.State.fullScreenCover,
        action: PresentationTestCase.Destination.Action.fullScreenCover
      ) { store in
        ChildView(store: store)
      }

      HStack {
        Button("Open navigation link demo") {
          viewStore.send(.navigationLinkDemoButtonTapped)
        }
        Spacer()
        Image(systemName: "arrow.up.forward.square")
      }
      .sheet(
        store: self.store.scope(
          state: \.$destination, action: PresentationTestCase.Action.destination),
        state: /PresentationTestCase.Destination.State.navigationLinkDemo,
        action: PresentationTestCase.Destination.Action.navigationLinkDemo
      ) { store in
        NavigationLinkDemoView(store: store)
      }

      Button("Open navigation destination") {
        self.viewStore.send(.navigationDestinationButtonTapped)
      }
      .navigationDestination(
        store: self.store.scope(
          state: \.$destination, action: PresentationTestCase.Action.destination),
        state: /PresentationTestCase.Destination.State.navigationDestination,
        action: PresentationTestCase.Destination.Action.navigationDestination
      ) { store in
        ChildView(store: store)
      }

      Button("Open popover") {
        self.viewStore.send(.popoverButtonTapped)
      }
      .popover(
        store: self.store.scope(
          state: \.$destination, action: PresentationTestCase.Action.destination),
        state: /PresentationTestCase.Destination.State.popover,
        action: PresentationTestCase.Destination.Action.popover
      ) { store in
        ChildView(store: store)
      }

      Button("Open sheet") {
        self.viewStore.send(.sheetButtonTapped)
      }
      .sheet(
        store: self.store.scope(
          state: \.$destination, action: PresentationTestCase.Action.destination),
        state: /PresentationTestCase.Destination.State.sheet,
        action: PresentationTestCase.Destination.Action.sheet
      ) { store in
        ChildView(store: store)
      }
    }
  }
}

private struct ChildView: View {
  let store: StoreOf<ChildFeature>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      VStack {
        Text("Count: \(viewStore.count)")
        TextField("Text field", text: viewStore.binding(\.$text))
        Button("Child dismiss") {
          viewStore.send(.childDismissButtonTapped)
        }
        Button("Increment") {
          viewStore.send(.incrementButtonTapped)
        }
        Button("Parent dismiss") {
          viewStore.send(.parentSendDismissActionButtonTapped)
        }
        Button("Start effect") {
          viewStore.send(.startButtonTapped)
        }
        Button("Reset identity") {
          viewStore.send(.resetIdentity)
        }
      }
    }
  }
}

private struct NavigationLinkDemoFeature: ReducerProtocol {
  struct State: Equatable {
    var message = ""
    @PresentationState var child: ChildFeature.State?
  }
  enum Action: Equatable {
    case child(PresentationAction<ChildFeature.Action>)
    case navigationLinkButtonTapped
  }
  var body: some ReducerProtocolOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .child(.presented) where state.child == nil:
        state.message = "Action sent while state nil."
        return .none
      default:
        return .none
      }
    }
    Reduce<State, Action> { state, action in
      switch action {
      case .child(.presented(.parentSendDismissActionButtonTapped)):
        state.child = nil
        return .none
      case .child:
        return .none
      case .navigationLinkButtonTapped:
        state.child = ChildFeature.State()
        return .none
      }
    }
    .ifLet(\.$child, action: /Action.child) {
      ChildFeature()
    }
  }
}

private struct NavigationLinkDemoView: View {
  let store: StoreOf<NavigationLinkDemoFeature>

  var body: some View {
    NavigationView {
      Form {
        WithViewStore(self.store, observe: \.message) { viewStore in
          Text(viewStore.state)
          
          NavigationLinkStore(
            store: self.store.scope(state: \.$child, action: NavigationLinkDemoFeature.Action.child)
          ) {
            viewStore.send(.navigationLinkButtonTapped)
          } destination: { store in
            ChildView(store: store)
          } label: {
            Text("Open navigation link")
          }
        }
      }
    }
  }
}
