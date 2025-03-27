import Combine
import SwiftUI

extension View {
  @_spi(Presentation)
  #if swift(<5.10)
    @MainActor(unsafe)
  #else
    @preconcurrency@MainActor
  #endif
  public func presentation<State, Action, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    @ViewBuilder body: @escaping (
      _ content: Self,
      _ isPresented: Binding<Bool>,
      _ destination: DestinationContent<State, Action>
    ) -> Content
  ) -> some View {
    self.presentation(store: store) { `self`, $item, destination in
      body(self, Binding($item), destination)
    }
  }

  @_disfavoredOverload
  @_spi(Presentation)
  #if swift(<5.10)
    @MainActor(unsafe)
  #else
    @preconcurrency@MainActor
  #endif
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
  #if swift(<5.10)
    @MainActor(unsafe)
  #else
    @preconcurrency@MainActor
  #endif
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
  #if swift(<5.10)
    @MainActor(unsafe)
  #else
    @preconcurrency@MainActor
  #endif
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
      body(self, Binding($item), destination)
    }
  }

  @_disfavoredOverload
  @_spi(Presentation)
  #if swift(<5.10)
    @MainActor(unsafe)
  #else
    @preconcurrency@MainActor
  #endif
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
  #if swift(<5.10)
    @MainActor(unsafe)
  #else
    @preconcurrency@MainActor
  #endif
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
      content(Binding($item), destination)
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
      content(Binding($item), destination)
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
    func open(
      _ core: some Core<PresentationState<State>, PresentationAction<Action>>
    ) -> any Core<PresentationState<State>, PresentationAction<Action>> {
      PresentationCore(base: core, toDestinationState: { $0 })
    }
    let store = store.scope(
      id: store.id(state: \.self, action: \.self),
      childCore: open(store.core)
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
    self.destinationStore = store.scope(state: \.wrappedValue, action: \.presented)
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
    func open(
      _ core: some Core<PresentationState<State>, PresentationAction<Action>>
    ) -> any Core<PresentationState<State>, PresentationAction<Action>> {
      PresentationCore(base: core, toDestinationState: toDestinationState)
    }
    let store = store.scope(
      id: store.id(state: \.self, action: \.self),
      childCore: open(store.core)
    )
    let viewStore = ViewStore(store, observe: { $0 }, removeDuplicates: { toID($0) == toID($1) })

    self.store = store
    self.toDestinationState = toDestinationState
    self.toID = toID
    self.fromDestinationAction = fromDestinationAction
    self.destinationStore = store._scope(
      state: { $0.wrappedValue.flatMap(toDestinationState) },
      action: { .presented(fromDestinationAction($0)) }
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

final class PresentationCore<
  Base: Core<PresentationState<State>, PresentationAction<Action>>,
  State,
  Action,
  DestinationState
>: Core {
  let base: Base
  let toDestinationState: (State) -> DestinationState?
  init(
    base: Base,
    toDestinationState: @escaping (State) -> DestinationState?
  ) {
    self.base = base
    self.toDestinationState = toDestinationState
  }
  var state: Base.State {
    base.state
  }
  func send(_ action: Base.Action) -> Task<Void, Never>? {
    base.send(action)
  }
  var canStoreCacheChildren: Bool { base.canStoreCacheChildren }
  var didSet: CurrentValueRelay<Void> { base.didSet }
  var isInvalid: Bool { state.wrappedValue.flatMap(toDestinationState) == nil || base.isInvalid }
  var effectCancellables: [UUID: AnyCancellable] { base.effectCancellables }
}

@_spi(Presentation)
public struct AnyIdentifiable: Identifiable {
  public let id: AnyHashable

  public init<Base: Identifiable>(_ base: Base) {
    self.id = base.id
  }
}

#if swift(<5.10)
  @MainActor(unsafe)
#else
  @preconcurrency@MainActor
#endif
@_spi(Presentation)
public struct DestinationContent<State, Action> {
  let store: Store<State?, Action>

  public func callAsFunction<Content: View>(
    @ViewBuilder _ body: @escaping (_ store: Store<State, Action>) -> Content
  ) -> some View {
    IfLetStore(self.store, then: body)
  }
}
