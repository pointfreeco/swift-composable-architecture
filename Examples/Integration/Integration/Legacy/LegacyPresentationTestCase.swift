@preconcurrency import ComposableArchitecture
import SwiftUI
import SwiftUINavigation

@Reducer
private struct PresentationTestCase {
  struct State: Equatable {
    var message = ""
    @PresentationState var destination: Destination.State?
  }
  enum Action: Equatable, Sendable {
    case alertButtonTapped
    case customAlertButtonTapped
    case destination(PresentationAction<Destination.Action>)
    case dialogButtonTapped
    case fullScreenCoverButtonTapped
    case navigationDestinationButtonTapped
    case navigationLinkDemoButtonTapped
    case popoverButtonTapped
    case sheetButtonTapped
  }

  @Reducer
  struct Destination {
    enum State: Equatable {
      case alert(AlertState<AlertAction>)
      case customAlert
      case dialog(ConfirmationDialogState<DialogAction>)
      case fullScreenCover(ChildFeature.State)
      case navigationDestination(ChildFeature.State)
      case navigationLinkDemo(NavigationLinkDemoFeature.State)
      case popover(ChildFeature.State)
      case sheet(ChildFeature.State)
    }
    enum Action: Equatable {
      case alert(AlertAction)
      case customAlert(AlertAction)
      case dialog(DialogAction)
      case fullScreenCover(ChildFeature.Action)
      case navigationDestination(ChildFeature.Action)
      case navigationLinkDemo(NavigationLinkDemoFeature.Action)
      case popover(ChildFeature.Action)
      case sheet(ChildFeature.Action)
    }
    enum AlertAction {
      case ok
      case showAlert
      case showDialog
      case showSheet
    }
    enum DialogAction {
      case ok
      case showAlert
      case showDialog
      case showSheet
    }
    var body: some ReducerOf<Self> {
      Scope(state: \.fullScreenCover, action: \.fullScreenCover) {
        ChildFeature()
      }
      Scope(state: \.navigationDestination, action: \.navigationDestination) {
        ChildFeature()
      }
      Scope(state: \.navigationLinkDemo, action: \.navigationLinkDemo) {
        NavigationLinkDemoFeature()
      }
      Scope(state: \.sheet, action: \.sheet) {
        ChildFeature()
      }
      Scope(state: \.popover, action: \.popover) {
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
            ButtonState(action: .showAlert) {
              TextState("Show alert")
            }
            ButtonState(action: .showDialog) {
              TextState("Show dialog")
            }
            ButtonState(action: .showSheet) {
              TextState("Show sheet")
            }
            ButtonState(role: .cancel) {
              TextState("Cancel")
            }
          }
        )
        return .none

      case .customAlertButtonTapped:
        state.destination = .customAlert
        return .none

      case .destination(.presented(.fullScreenCover(.parentSendDismissActionButtonTapped))),
        .destination(.presented(.sheet(.parentSendDismissActionButtonTapped))),
        .destination(.presented(.popover(.parentSendDismissActionButtonTapped))):
        return .send(.destination(.dismiss))

      case let .destination(.presented(.alert(alertAction))):
        switch alertAction {
        case .ok:
          return .none
        case .showAlert:
          state.destination = .alert(
            AlertState {
              TextState("Hello again!")
            } actions: {
            }
          )
          return .none
        case .showDialog:
          state.destination = .dialog(
            ConfirmationDialogState(titleVisibility: .visible) {
              TextState("Hello!")
            } actions: {
            }
          )
          return .none
        case .showSheet:
          state.destination = .sheet(ChildFeature.State())
          return .none
        }

      case let .destination(.presented(.dialog(dialogAction))):
        switch dialogAction {
        case .ok:
          return .none
        case .showAlert:
          state.destination = .alert(
            AlertState {
              TextState("Hello!")
            } actions: {
            }
          )
          return .none
        case .showDialog:
          state.destination = .dialog(
            ConfirmationDialogState(titleVisibility: .visible) {
              TextState("Hello again!")
            } actions: {
            }
          )
          return .none
        case .showSheet:
          state.destination = .sheet(ChildFeature.State())
          return .none
        }

      case .destination(.presented(.fullScreenCover(.dismissAndAlert))),
        .destination(.presented(.popover(.dismissAndAlert))),
        .destination(.presented(.navigationDestination(.dismissAndAlert))),
        .destination(.presented(.sheet(.dismissAndAlert))):
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
            ButtonState(action: .showDialog) {
              TextState("Show dialog")
            }
            ButtonState(action: .showSheet) {
              TextState("Show sheet")
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
    .ifLet(\.$destination, action: \.destination) {
      Destination()
    }
  }
}

@Reducer
private struct ChildFeature {
  struct State: Equatable, Identifiable {
    var id = UUID()
    var count = 0
    var isDismissed = false
    @BindingState var text = ""
  }
  enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case childDismissButtonTapped
    case dismissAndAlert
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
        state.isDismissed = true
        return .run { _ in await self.dismiss() }
      case .dismissAndAlert:
        return .none
      case .incrementButtonTapped:
        state.count += 1
        return .none
      case .parentSendDismissActionButtonTapped:
        state.isDismissed = true
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
  @StateObject private var viewStore: ViewStoreOf<PresentationTestCase>
  @State var alertMessage = ""

  init() {
    let store = Store(initialState: PresentationTestCase.State()) {
      PresentationTestCase()
        ._printChanges()
    }
    self.store = store
    self._viewStore = StateObject(
      wrappedValue: ViewStore(store, observe: { $0 })
    )
  }

  var body: some View {
    Form {
      Section {
        Text(self.viewStore.message)
        Text(self.alertMessage)
      }

      Button("Open alert") {
        self.viewStore.send(.alertButtonTapped)
      }
      .alert(store: self.store.scope(state: \.$destination.alert, action: \.destination.alert))

      Button("Open custom alert") {
        self.viewStore.send(.customAlertButtonTapped)
      }
      .alert(
        "Custom alert!",
        isPresented:
          viewStore
          .binding(get: \.destination, send: .destination(.dismiss))
          .customAlert
          .isPresent()
      ) {
        TextField("Message", text: self.$alertMessage)
        Button("Submit") {}
        Button("Cancel", role: .cancel) {}
      }

      Button("Open dialog") {
        self.viewStore.send(.dialogButtonTapped)
      }
      .confirmationDialog(
        store: self.store.scope(state: \.$destination.dialog, action: \.destination.dialog)
      )

      Button("Open full screen cover") {
        self.viewStore.send(.fullScreenCoverButtonTapped)
      }
      .fullScreenCover(
        store: self.store.scope(
          state: \.$destination.fullScreenCover,
          action: \.destination.fullScreenCover
        )
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
          state: \.$destination.navigationLinkDemo, action: \.destination.navigationLinkDemo
        )
      ) { store in
        NavigationLinkDemoView(store: store)
      }

      Button("Open navigation destination") {
        self.viewStore.send(.navigationDestinationButtonTapped)
      }
      .navigationDestination(
        store: self.store.scope(
          state: \.$destination.navigationDestination, action: \.destination.navigationDestination
        )
      ) { store in
        ChildView(store: store)
      }

      Button("Open popover") {
        self.viewStore.send(.popoverButtonTapped)
      }
      .popover(
        store: self.store.scope(state: \.$destination.popover, action: \.destination.popover)
      ) { store in
        ChildView(store: store)
      }

      Button("Open sheet") {
        self.viewStore.send(.sheetButtonTapped)
      }
      .sheet(
        store: self.store.scope(state: \.$destination.sheet, action: \.destination.sheet)
      ) { store in
        ChildView(store: store)
      }
    }
  }
}

private struct ChildView: View {
  @Environment(\.dismiss) var dismiss
  let store: StoreOf<ChildFeature>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      VStack {
        Text("Count: \(viewStore.count)")
        TextField("Text field", text: viewStore.$text)
        Button("Child dismiss") {
          viewStore.send(.childDismissButtonTapped)
        }
        Button("Increment") {
          viewStore.send(.incrementButtonTapped)
        }
        Button("Parent dismiss") {
          viewStore.send(.parentSendDismissActionButtonTapped)
        }
        Button("Dismiss and alert") {
          viewStore.send(.dismissAndAlert)
        }
        Button("Start effect") {
          viewStore.send(.startButtonTapped)
        }
        Button("Reset identity") {
          viewStore.send(.resetIdentity)
        }
      }
      .onChange(of: viewStore.isDismissed) { _ in
        self.dismiss()
      }
    }
  }
}

@Reducer
private struct NavigationLinkDemoFeature {
  struct State: Equatable {
    var message = ""
    @PresentationState var child: ChildFeature.State?
    @PresentationState var identifiedChild: ChildFeature.State?
  }
  enum Action: Equatable {
    case child(PresentationAction<ChildFeature.Action>)
    case identifiedChild(PresentationAction<ChildFeature.Action>)
    case identifiedNavigationLinkButtonTapped
    case navigationLinkButtonTapped
    case nonDeadbeefIdentifiedNavigationLinkButtonTapped
  }
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .child(.presented) where state.child == nil:
        state.message = "Action sent while state nil."
        return .none
      default:
        return .none
      }
    }
    Reduce { state, action in
      switch action {
      case .child(.presented(.parentSendDismissActionButtonTapped)):
        state.child = nil
        return .none
      case .identifiedChild(.presented(.parentSendDismissActionButtonTapped)):
        state.child = nil
        return .none
      case .child, .identifiedChild:
        return .none
      case .identifiedNavigationLinkButtonTapped:
        state.identifiedChild = ChildFeature.State(
          id: UUID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!
        )
        return .none
      case .navigationLinkButtonTapped:
        state.child = ChildFeature.State()
        return .none
      case .nonDeadbeefIdentifiedNavigationLinkButtonTapped:
        state.identifiedChild = ChildFeature.State()
        return .none
      }
    }
    .ifLet(\.$child, action: \.child) {
      ChildFeature()
    }
    .ifLet(\.$identifiedChild, action: \.identifiedChild) {
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
            self.store.scope(state: \.$child, action: \.child)
          ) {
            viewStore.send(.navigationLinkButtonTapped)
          } destination: { store in
            ChildView(store: store)
          } label: {
            Text("Open navigation link")
          }

          NavigationLinkStore(
            self.store.scope(state: \.$identifiedChild, action: \.identifiedChild),
            id: UUID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!
          ) {
            viewStore.send(.identifiedNavigationLinkButtonTapped)
          } destination: { store in
            ChildView(store: store)
          } label: {
            Text("Open identified navigation link")
          }

          Button("Open non-deadbeef identified navigation link") {
            viewStore.send(.nonDeadbeefIdentifiedNavigationLinkButtonTapped)
          }
        }
      }
    }
  }
}
