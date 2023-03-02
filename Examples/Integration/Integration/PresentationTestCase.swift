@preconcurrency import ComposableArchitecture
import SwiftUI

private struct PresentationTestCase: ReducerProtocol {
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
    case navigationLinkButtonTapped
    case popoverButtonTapped
    case sheetButtonTapped
  }

  struct Destination: ReducerProtocol {
    enum State: Equatable {
      case alert(AlertState<AlertAction>)
      case dialog(ConfirmationDialogState<DialogAction>)
      case fullScreenCover(ChildFeature.State)
      case navigationDestination(ChildFeature.State)
      case navigationLink(ChildFeature.State)
      case popover(ChildFeature.State)
      case sheet(ChildFeature.State)
    }
    enum Action: Equatable {
      case alert(AlertAction)
      case dialog(DialogAction)
      case fullScreenCover(ChildFeature.Action)
      case navigationDestination(ChildFeature.Action)
      case navigationLink(ChildFeature.Action)
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
    var body: some ReducerProtocolOf<Self> {
      Scope(state: /State.fullScreenCover, action: /Action.fullScreenCover) {
        ChildFeature()
      }
      Scope(state: /State.navigationDestination, action: /Action.navigationDestination) {
        ChildFeature()
      }
      Scope(state: /State.navigationLink, action: /Action.navigationLink) {
        ChildFeature()
      }
      Scope(state: /State.sheet, action: /Action.sheet) {
        ChildFeature()
      }
      Scope(state: /State.popover, action: /Action.popover) {
        ChildFeature()
      }
    }
  }

  var body: some ReducerProtocolOf<Self> {
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
        .destination(.presented(.navigationLink(.parentSendDismissActionButtonTapped))),
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
      case .navigationLinkButtonTapped:
        state.destination = .navigationLink(ChildFeature.State())
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

private struct ChildFeature: ReducerProtocol {
  struct State: Equatable, Identifiable {
    var id = UUID()
    var count = 0
  }
  enum Action {
    case childDismissButtonTapped
    case incrementButtonTapped
    case parentSendDismissActionButtonTapped
    case resetIdentity
    case response
    case startButtonTapped
  }
  @Dependency(\.dismiss) var dismiss
  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
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
        try await Task.sleep(for: .seconds(3))
        await send(.response)
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

      NavigationLinkStore(
        store: self.store.scope(
          state: \.$destination, action: PresentationTestCase.Action.destination),
        state: /PresentationTestCase.Destination.State.navigationLink,
        action: PresentationTestCase.Destination.Action.navigationLink
      ) {
        self.viewStore.send(.navigationLinkButtonTapped)
      } destination: { store in
        ChildView(store: store)
      } label: {
        Text("Open navigation link")
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
