import SwiftUI

extension View {
  @_spi(Presentation)
  public func presentation<State, Action, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    @ViewBuilder body: @escaping (
      _ content: Self,
      _ isPresented: Binding<Bool>,
      _ destination: DestinationContent<State, Action>
    ) -> Content
  ) -> some View {
    self.presentation(store: store) { `self`, $item, destination in
      body(self, $item.isPresent(), destination)
    }
  }

  @_disfavoredOverload
  @_spi(Presentation)
  public func presentation<State, Action, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    @ViewBuilder body: @escaping (
      _ content: Self,
      _ item: Binding<AnyIdentifiable?>,
      _ destination: DestinationContent<State, Action>
    ) -> Content
  ) -> some View {
    self.presentation(
      store: store,
      id: { $0.wrappedValue.map { _ in ObjectIdentifier(State.self) } }
    ) { `self`, $item, destination in
      body(self, $item, destination)
    }
  }

  @_disfavoredOverload
  @_spi(Presentation)
  public func presentation<State, Action, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    id toID: @escaping (PresentationState<State>) -> AnyHashable?,
    @ViewBuilder body: @escaping (
      _ content: Self,
      _ item: Binding<AnyIdentifiable?>,
      _ destination: DestinationContent<State, Action>
    ) -> Content
  ) -> some View {
    PresentationStore(store, id: toID) { $item, destination in
      body(self, $item, destination)
    }
  }

  @_spi(Presentation)
  public func presentation<
    State,
    Action,
    DestinationState,
    DestinationAction,
    Content: View
  >(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (_ state: State) -> DestinationState?,
    action fromDestinationAction: @escaping (_ destinationAction: DestinationAction) -> Action,
    @ViewBuilder body: @escaping (
      _ content: Self,
      _ isPresented: Binding<Bool>,
      _ destination: DestinationContent<DestinationState, DestinationAction>
    ) -> Content
  ) -> some View {
    self.presentation(
      store: store, state: toDestinationState, action: fromDestinationAction
    ) { `self`, $item, destination in
      body(self, $item.isPresent(), destination)
    }
  }

  @_disfavoredOverload
  @_spi(Presentation)
  public func presentation<
    State,
    Action,
    DestinationState,
    DestinationAction,
    Content: View
  >(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (_ state: State) -> DestinationState?,
    action fromDestinationAction: @escaping (_ destinationAction: DestinationAction) -> Action,
    @ViewBuilder body: @escaping (
      _ content: Self,
      _ item: Binding<AnyIdentifiable?>,
      _ destination: DestinationContent<DestinationState, DestinationAction>
    ) -> Content
  ) -> some View {
    self.presentation(
      store: store,
      state: toDestinationState,
      id: { $0.id },
      action: fromDestinationAction,
      body: body
    )
  }

  @_spi(Presentation)
  @ViewBuilder
  public func presentation<
    State,
    Action,
    DestinationState,
    DestinationAction,
    Content: View
  >(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (State) -> DestinationState?,
    id toID: @escaping (PresentationState<State>) -> AnyHashable?,
    action fromDestinationAction: @escaping (DestinationAction) -> Action,
    @ViewBuilder body: @escaping (
      Self,
      Binding<AnyIdentifiable?>,
      DestinationContent<DestinationState, DestinationAction>
    ) -> Content
  ) -> some View {
    PresentationStore(
      store, state: toDestinationState, id: toID, action: fromDestinationAction
    ) { $item, destination in
      body(self, $item, destination)
    }
  }
}

@_spi(Presentation)
public struct PresentationStore<
  State, Action, DestinationState, DestinationAction, Content: View
>: View {
  let store: Store<PresentationState<State>, PresentationAction<Action>>
  let toDestinationState: (State) -> DestinationState?
  let toID: (PresentationState<State>) -> AnyHashable?
  let fromDestinationAction: (DestinationAction) -> Action
  let destinationStore: Store<DestinationState?, DestinationAction>
  let content:
    (
      Binding<AnyIdentifiable?>,
      DestinationContent<DestinationState, DestinationAction>
    ) -> Content

  @ObservedObject var viewStore: ViewStore<PresentationState<State>, PresentationAction<Action>>

  public init(
    _ store: Store<PresentationState<State>, PresentationAction<Action>>,
    @ViewBuilder content: @escaping (
      _ isPresented: Binding<Bool>,
      _ destination: DestinationContent<DestinationState, DestinationAction>
    ) -> Content
  ) where State == DestinationState, Action == DestinationAction {
    self.init(store) { $item, destination in
      content($item.isPresent(), destination)
    }
  }

  @_disfavoredOverload
  public init(
    _ store: Store<PresentationState<State>, PresentationAction<Action>>,
    @ViewBuilder content: @escaping (
      _ item: Binding<AnyIdentifiable?>,
      _ destination: DestinationContent<DestinationState, DestinationAction>
    ) -> Content
  ) where State == DestinationState, Action == DestinationAction {
    self.init(
      store,
      id: { $0.id },
      content: content
    )
  }

  public init(
    _ store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (_ state: State) -> DestinationState?,
    action fromDestinationAction: @escaping (_ destinationAction: DestinationAction) -> Action,
    @ViewBuilder content: @escaping (
      _ isPresented: Binding<Bool>,
      _ destination: DestinationContent<DestinationState, DestinationAction>
    ) -> Content
  ) {
    self.init(
      store, state: toDestinationState, action: fromDestinationAction
    ) { $item, destination in
      content($item.isPresent(), destination)
    }
  }

  @_disfavoredOverload
  public init(
    _ store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (_ state: State) -> DestinationState?,
    action fromDestinationAction: @escaping (_ destinationAction: DestinationAction) -> Action,
    @ViewBuilder content: @escaping (
      _ item: Binding<AnyIdentifiable?>,
      _ destination: DestinationContent<DestinationState, DestinationAction>
    ) -> Content
  ) {
    self.init(
      store,
      state: toDestinationState,
      id: { $0.id },
      action: fromDestinationAction,
      content: content
    )
  }

  fileprivate init<ID: Hashable>(
    _ store: Store<PresentationState<State>, PresentationAction<Action>>,
    id toID: @escaping (PresentationState<State>) -> ID?,
    content: @escaping (
      _ item: Binding<AnyIdentifiable?>,
      _ destination: DestinationContent<DestinationState, DestinationAction>
    ) -> Content
  ) where State == DestinationState, Action == DestinationAction {
    let store = store.scope(
      id: store.id(state: \.self, action: \.self),
      state: ToState(\.self),
      action: { $0 },
      isInvalid: { $0.wrappedValue == nil }
    )
    let viewStore = ViewStore(
      store,
      observe: { $0 },
      removeDuplicates: { toID($0) == toID($1) }
    )

    self.store = store
    self.toDestinationState = { $0 }
    self.toID = toID
    self.fromDestinationAction = { $0 }
    self.destinationStore = store.scope(
      id: store.id(state: \.wrappedValue, action: \.presented),
      state: ToState(\.wrappedValue),
      action: { .presented($0) },
      isInvalid: nil
    )
    self.content = content
    self.viewStore = viewStore
  }

  fileprivate init<ID: Hashable>(
    _ store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (State) -> DestinationState?,
    id toID: @escaping (PresentationState<State>) -> ID?,
    action fromDestinationAction: @escaping (DestinationAction) -> Action,
    content: @escaping (
      _ item: Binding<AnyIdentifiable?>,
      _ destination: DestinationContent<DestinationState, DestinationAction>
    ) -> Content
  ) {
    let store = store.scope(
      id: nil,
      state: ToState(\.self),
      action: { $0 },
      isInvalid: { $0.wrappedValue.flatMap(toDestinationState) == nil }
    )
    let viewStore = ViewStore(store, observe: { $0 }, removeDuplicates: { toID($0) == toID($1) })

    self.store = store
    self.toDestinationState = toDestinationState
    self.toID = toID
    self.fromDestinationAction = fromDestinationAction
    self.destinationStore = store.scope(
      id: nil,
      state: ToState { $0.wrappedValue.flatMap(toDestinationState) },
      action: { .presented(fromDestinationAction($0)) },
      isInvalid: nil
    )
    self.content = content
    self.viewStore = viewStore
  }

  public var body: some View {
    let id = self.toID(self.viewStore.state)
    self.content(
      self.viewStore.binding(
        get: {
          $0.wrappedValue.flatMap(toDestinationState) != nil
            ? toID($0).map { AnyIdentifiable(Identified($0) { $0 }) }
            : nil
        },
        compactSend: { [weak viewStore = self.viewStore] in
          guard
            let viewStore = viewStore,
            $0 == nil,
            viewStore.wrappedValue != nil,
            id == nil || self.toID(viewStore.state) == id
          else { return nil }
          return .dismiss
        }
      ),
      DestinationContent(store: self.destinationStore)
    )
  }
}

@_spi(Presentation)
public struct AnyIdentifiable: Identifiable {
  public let id: AnyHashable

  public init<Base: Identifiable>(_ base: Base) {
    self.id = base.id
  }
}

@_spi(Presentation)
public struct DestinationContent<State, Action> {
  let store: Store<State?, Action>

  public func callAsFunction<Content: View>(
    @ViewBuilder _ body: @escaping (_ store: Store<State, Action>) -> Content
  ) -> some View {
    IfLetStore(
      self.store.scope(
        id: self.store.id(state: \.self, action: \.self),
        state: ToState(returningLastNonNilValue { $0 }),
        action: { $0 },
        isInvalid: nil
      ),
      then: body
    )
  }
}
