import SwiftUI

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
@MainActor
extension View {
  public func alert<ButtonAction>(
    store: Store<
      PresentationState<AlertState<ButtonAction>>,
      PresentationAction<ButtonAction>
    >
  ) -> some View {
    self.alert(store: store, state: { $0 }, action: { $0 })
  }

  public func alert<State, Action, ButtonAction>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (State) -> AlertState<ButtonAction>?,
    action fromDestinationAction: @escaping (ButtonAction) -> Action
  ) -> some View {
    WithViewStore(store) {
      $0
    } removeDuplicates: {
      $0.id == $1.id
    } content: { viewStore in
      let alertState = viewStore.wrappedValue.flatMap(toDestinationState)
      return self.alert(
        (alertState?.title).map(Text.init) ?? Text(""),
        isPresented: Binding(
          get: { alertState != nil },
          set: { _ in
            if viewStore.wrappedValue.flatMap(toDestinationState) != nil {
              viewStore.send(.dismiss)
            }
          }
        ),
        presenting: alertState,
        actions: { alertState in
          ForEach(alertState.buttons) { button in
            Button(role: button.role.map(ButtonRole.init)) {
              switch button.action.type {
              case let .send(action):
                if let action = action {
                  viewStore.send(.presented(fromDestinationAction(action)))
                }
              case let .animatedSend(action, animation):
                if let action = action {
                  _ = withAnimation(animation) {
                    viewStore.send(.presented(fromDestinationAction(action)))
                  }
                }
              }
            } label: {
              Text(button.label)
            }
          }
        },
        message: {
          $0.message.map(Text.init) ?? Text("")
        }
      )
    }
  }

  public func confirmationDialog<ButtonAction>(
    store: Store<
      PresentationState<ConfirmationDialogState<ButtonAction>>,
      PresentationAction<ButtonAction>
    >
  ) -> some View {
    self.confirmationDialog(store: store, state: { $0 }, action: { $0 })
  }

  public func confirmationDialog<State, Action, ButtonAction>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (State) -> ConfirmationDialogState<ButtonAction>?,
    action fromDestinationAction: @escaping (ButtonAction) -> Action
  ) -> some View {
    WithViewStore(store) {
      $0
    } removeDuplicates: {
      $0.id == $1.id
    } content: { viewStore in
      let confirmationDialogState = viewStore.wrappedValue.flatMap(toDestinationState)
      return self.confirmationDialog(
        (confirmationDialogState?.title).map(Text.init) ?? Text(""),
        isPresented: Binding(
          get: { confirmationDialogState != nil },
          set: { _ in
            if viewStore.wrappedValue.flatMap(toDestinationState) != nil {
              viewStore.send(.dismiss)
            }
          }
        ),
        titleVisibility: (confirmationDialogState?.titleVisibility).map(Visibility.init)
          ?? .automatic,
        presenting: confirmationDialogState,
        actions: { confirmationDialogState in
          ForEach(confirmationDialogState.buttons) { button in
            Button(role: button.role.map(ButtonRole.init)) {
              switch button.action.type {
              case let .send(action):
                if let action = action {
                  viewStore.send(.presented(fromDestinationAction(action)))
                }
              case let .animatedSend(action, animation):
                if let action = action {
                  _ = withAnimation(animation) {
                    viewStore.send(.presented(fromDestinationAction(action)))
                  }
                }
              }
            } label: {
              Text(button.label)
            }
          }
        },
        message: {
          $0.message.map(Text.init) ?? Text("")
        }
      )
    }
  }
}

extension View {
  @available(iOS 14, tvOS 14, watchOS 7, *)
  @available(macOS, unavailable)
  public func fullScreenCover<State, Action, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    @ViewBuilder content: @escaping (Store<State, Action>) -> Content
  ) -> some View {
    self.fullScreenCover(store: store, state: { $0 }, action: { $0 }, content: content)
  }

  @available(iOS 14, tvOS 14, watchOS 7, *)
  @available(macOS, unavailable)
  public func fullScreenCover<State, Action, DestinationState, DestinationAction, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (State) -> DestinationState?,
    action fromDestinationAction: @escaping (DestinationAction) -> Action,
    @ViewBuilder content: @escaping (Store<DestinationState, DestinationAction>) -> Content
  ) -> some View {
    WithViewStore(
      store.filter { state, _ in state.wrappedValue != nil },
      removeDuplicates: { $0.id == $1.id }
    ) { viewStore in
      self.fullScreenCover(
        item: viewStore.binding(
          get: { $0.wrappedValue.flatMap(toDestinationState) != nil ? $0.id : nil },
          send: .dismiss
        )
      ) { _ in
        IfLetStore(
          store.scope(
            state: returningLastNonNilValue { $0.wrappedValue.flatMap(toDestinationState) },
            action: { .presented(fromDestinationAction($0)) }
          ),
          then: content
        )
      }
    }
  }

  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public func popover<State, Action, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds),
    arrowEdge: Edge = .top,
    @ViewBuilder content: @escaping (Store<State, Action>) -> Content
  ) -> some View {
    self.popover(
      store: store,
      state: { $0 },
      action: { $0 },
      attachmentAnchor: attachmentAnchor,
      arrowEdge: arrowEdge,
      content: content
    )
  }

  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public func popover<State, Action, DestinationState, DestinationAction, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (State) -> DestinationState?,
    action fromDestinationAction: @escaping (DestinationAction) -> Action,
    attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds),
    arrowEdge: Edge = .top,
    @ViewBuilder content: @escaping (Store<DestinationState, DestinationAction>) -> Content
  ) -> some View {
    WithViewStore(
      store.filter { state, _ in state.wrappedValue != nil },
      removeDuplicates: { $0.id == $1.id }
    ) { viewStore in
      self.popover(
        // item: viewStore.binding(
        //   get: { $0.wrappedValue.flatMap(toDestinationState) != nil ? $0.id : nil },
        //   send: { id in
        //     print("id", id)
        //     print("viewStore.id", viewStore.id)
        //     print("store.state.value.id", store.state.value.id)
        //     print("viewStore.id == store.state.value.id", viewStore.id == store.state.value.id)
        //     return .dismiss
        //   }
        // )
        item: Binding(
          get: { viewStore.wrappedValue.flatMap(toDestinationState) != nil ? viewStore.id : nil },
          set: { _ in }
        )
      ) { id in
        IfLetStore(
          store.scope(
            state: returningLastNonNilValue { $0.wrappedValue.flatMap(toDestinationState) },
            action: { .presented(fromDestinationAction($0)) }
          )
        ) { sheetStore in
          content(sheetStore)
          // .onDisappear {
          //   // NB: Swapping presented items introduces a bug in which the item binding never
          //   //     writes `nil` and `onDismiss` is never called when the sheet is swiped away.
          //   //
          //   //     This `onDisappear` is a workaround to maintain dismissed state.
          //   if store.state.value.id == id {
          //     viewStore.binding(send: .dismiss).wrappedValue = .dismissed
          //   }
          // }
        }
      }
    }
  }

  public func sheet<State, Action, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    @ViewBuilder content: @escaping (Store<State, Action>) -> Content
  ) -> some View {
    self.sheet(store: store, state: { $0 }, action: { $0 }, content: content)
  }

  public func sheet<State, Action, DestinationState, DestinationAction, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (State) -> DestinationState?,
    action fromDestinationAction: @escaping (DestinationAction) -> Action,
    @ViewBuilder content: @escaping (Store<DestinationState, DestinationAction>) -> Content
  ) -> some View {
    WithViewStore(
      store.filter { state, _ in state.wrappedValue != nil },
      removeDuplicates: { $0.id == $1.id }
    ) { viewStore in
      self.sheet(
        item: viewStore.binding(
          get: { $0.wrappedValue.flatMap(toDestinationState) != nil ? $0.id : nil },
          send: .dismiss
        )
      ) { id in
        IfLetStore(
          store.scope(
            state: returningLastNonNilValue { $0.wrappedValue.flatMap(toDestinationState) },
            action: { .presented(fromDestinationAction($0)) }
          )
        ) { sheetStore in
          content(sheetStore)
            .onDisappear {
              // NB: Swapping presented items introduces a bug in which the item binding never
              //     writes `nil` and `onDismiss` is never called when the sheet is swiped away.
              //     This `onDisappear` is a workaround to maintain dismissed state.
              //
              // Feedback filed: https://gist.github.com/mbrandonw/f8b94957031160336cac6898a919cbb7#file-fb11975674-md
              if store.state.value.id == id {
                viewStore.send(.dismiss)
              }
            }
        }
      }
    }
  }

  // TODO: Confusing to define `navigationDestination` for both `{Presentation,Navigation}State`?
  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  public func navigationDestination<State, Action, Destination: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    @ViewBuilder destination: @escaping (Store<State, Action>) -> Destination
  ) -> some View {
    self.navigationDestination(
      store: store, state: { $0 }, action: { $0 }, destination: destination
    )
  }

  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  public func navigationDestination<
    State, Action, DestinationState, DestinationAction, Destination: View
  >(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (State) -> DestinationState?,
    action fromDestinationAction: @escaping (DestinationAction) -> Action,
    @ViewBuilder destination: @escaping (Store<DestinationState, DestinationAction>) -> Destination
  ) -> some View {
    WithViewStore(
      store
        .filter { state, _ in state.wrappedValue != nil }
        .scope(state: { $0.wrappedValue.flatMap(toDestinationState) != nil })
    ) { viewStore in
      self.navigationDestination(isPresented: viewStore.binding(send: .dismiss)) {
        IfLetStore(
          store.scope(
            state: returningLastNonNilValue { $0.wrappedValue.flatMap(toDestinationState) },
            action: { .presented(fromDestinationAction($0)) }
          ),
          then: destination
        )
      }
    }
  }
}

// TODO: Support deprecated `NavigationLink` APIs

// TODO: Do we want this alternative to `IfLetStore`? Should it be an `IfLetStore.init` overload?
public struct PresentationStore<
  State,
  Action,
  DestinationState,
  DestinationAction,
  Destination: View,
  Dismissed: View
>: View {
  let store: Store<PresentationState<State>, PresentationAction<Action>>
  let toDestinationState: (State) -> DestinationState?
  let fromDestinationAction: (DestinationAction) -> Action
  let destination: (Store<DestinationState, DestinationAction>) -> Destination
  let dismissed: Dismissed

  public init(
    _ store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (State) -> DestinationState?,
    action fromDestinationAction: @escaping (DestinationAction) -> Action,
    @ViewBuilder destination: @escaping (Store<DestinationState, DestinationAction>) -> Destination,
    @ViewBuilder dismissed: () -> Dismissed
  ) {
    self.store = store
    self.toDestinationState = toDestinationState
    self.fromDestinationAction = fromDestinationAction
    self.destination = destination
    self.dismissed = dismissed()
  }

  public init(
    _ store: Store<PresentationState<State>, PresentationAction<Action>>,
    @ViewBuilder destination: @escaping (Store<DestinationState, DestinationAction>) -> Destination,
    @ViewBuilder dismissed: () -> Dismissed
  ) where State == DestinationState, Action == DestinationAction {
    self.store = store
    self.toDestinationState = { $0 }
    self.fromDestinationAction = { $0 }
    self.destination = destination
    self.dismissed = dismissed()
  }

  public var body: some View {
    IfLetStore(
      self.store.scope(
        state: { $0.wrappedValue.flatMap(toDestinationState) },
        action: { .presented(fromDestinationAction($0)) }
      )
    ) { store in
      self.destination(store)
    } else: {
      self.dismissed
    }
  }
}
