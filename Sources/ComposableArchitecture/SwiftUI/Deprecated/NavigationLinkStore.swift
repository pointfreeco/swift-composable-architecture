import Combine
import SwiftUI

/// A view that controls a navigation presentation.
///
/// This view is similar to SwiftUI's `NavigationLink`, but it allows driving navigation from an
/// optional or enum instead of just a boolean.
///
/// Typically you use this view by first modeling your features as having a parent feature that
/// holds onto an optional piece of child state using the ``PresentationState``,
/// ``PresentationAction`` and ``Reducer/ifLet(_:action:destination:fileID:filePath:line:column:)-4ub6q`` tools (see
/// <doc:TreeBasedNavigation> for more information). Then in the view you can construct a
/// `NavigationLinkStore` by passing a ``Store`` that is focused on the presentation domain:
///
/// ```swift
/// NavigationLinkStore(
///   self.store.scope(state: \.$child, action: \.child)
/// ) {
///   viewStore.send(.linkTapped)
/// } destination: { store in
///   ChildView(store: store)
/// } label: {
///   Text("Go to child")
/// }
/// ```
///
/// Then when the `child` state flips from `nil` to non-`nil` a drill-down animation will occur to
/// the child domain.
@available(iOS, introduced: 13, deprecated: 16)
@available(macOS, introduced: 10.15, deprecated: 13)
@available(tvOS, introduced: 13, deprecated: 16)
@available(watchOS, introduced: 6, deprecated: 9)
public struct NavigationLinkStore<
  State,
  Action,
  DestinationState,
  DestinationAction,
  Destination: View,
  Label: View
>: View {
  let store: Store<PresentationState<State>, PresentationAction<Action>>
  @ObservedObject var viewStore: ViewStore<Bool, PresentationAction<Action>>
  let toDestinationState: (State) -> DestinationState?
  let fromDestinationAction: (DestinationAction) -> Action
  let onTap: () -> Void
  let destination: (Store<DestinationState, DestinationAction>) -> Destination
  let label: Label
  var isDetailLink = true

  public init(
    _ store: Store<PresentationState<State>, PresentationAction<Action>>,
    onTap: @escaping () -> Void,
    @ViewBuilder destination: @escaping (_ store: Store<State, Action>) -> Destination,
    @ViewBuilder label: () -> Label
  ) where State == DestinationState, Action == DestinationAction {
    self.init(
      store,
      state: { $0 },
      action: { $0 },
      onTap: onTap,
      destination: destination,
      label: label
    )
  }

  public init(
    _ store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (_ state: State) -> DestinationState?,
    action fromDestinationAction: @escaping (_ destinationAction: DestinationAction) -> Action,
    onTap: @escaping () -> Void,
    @ViewBuilder destination: @escaping (_ store: Store<DestinationState, DestinationAction>) ->
      Destination,
    @ViewBuilder label: () -> Label
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
    self.store = store
    self.viewStore = ViewStore(
      store._scope(
        state: { $0.wrappedValue.flatMap(toDestinationState) != nil },
        action: { $0 }
      ),
      observe: { $0 }
    )
    self.toDestinationState = toDestinationState
    self.fromDestinationAction = fromDestinationAction
    self.onTap = onTap
    self.destination = destination
    self.label = label()
  }

  public init(
    _ store: Store<PresentationState<State>, PresentationAction<Action>>,
    id: State.ID,
    onTap: @escaping () -> Void,
    @ViewBuilder destination: @escaping (_ store: Store<State, Action>) -> Destination,
    @ViewBuilder label: () -> Label
  ) where State == DestinationState, Action == DestinationAction, State: Identifiable {
    self.init(
      store,
      state: { $0 },
      action: { $0 },
      id: id,
      onTap: onTap,
      destination: destination,
      label: label
    )
  }

  public init(
    _ store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (_ state: State) -> DestinationState?,
    action fromDestinationAction: @escaping (_ destinationAction: DestinationAction) -> Action,
    id: DestinationState.ID,
    onTap: @escaping () -> Void,
    @ViewBuilder destination: @escaping (_ store: Store<DestinationState, DestinationAction>) ->
      Destination,
    @ViewBuilder label: () -> Label
  ) where DestinationState: Identifiable {
    func open(
      _ core: some Core<PresentationState<State>, PresentationAction<Action>>
    ) -> any Core<PresentationState<State>, PresentationAction<Action>> {
      NavigationLinkCore(base: core, id: id, toDestinationState: toDestinationState)
    }
    let store = store.scope(
      id: store.id(state: \.self, action: \.self),
      childCore: open(store.core)
    )
    self.store = store
    self.viewStore = ViewStore(
      store._scope(
        state: { $0.wrappedValue.flatMap(toDestinationState)?.id == id },
        action: { $0 }
      ),
      observe: { $0 }
    )
    self.toDestinationState = toDestinationState
    self.fromDestinationAction = fromDestinationAction
    self.onTap = onTap
    self.destination = destination
    self.label = label()
  }

  public var body: some View {
    NavigationLink(
      isActive: Binding(
        get: { self.viewStore.state },
        set: {
          if $0 {
            withTransaction($1, self.onTap)
          } else if self.viewStore.state {
            self.viewStore.send(.dismiss, transaction: $1)
          }
        }
      )
    ) {
      IfLetStore(
        self.store._scope(
          state: returningLastNonNilValue { $0.wrappedValue.flatMap(self.toDestinationState) },
          action: { .presented(self.fromDestinationAction($0)) }
        ),
        then: self.destination
      )
    } label: {
      self.label
    }
    #if os(iOS)
      .isDetailLink(self.isDetailLink)
    #endif
  }

  @available(macOS, unavailable)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public func isDetailLink(_ isDetailLink: Bool) -> Self {
    var link = self
    link.isDetailLink = isDetailLink
    return link
  }
}

private final class NavigationLinkCore<
  Base: Core<PresentationState<State>, PresentationAction<Action>>,
  State,
  Action,
  DestinationState: Identifiable
>: Core {
  let base: Base
  let id: DestinationState.ID
  let toDestinationState: (State) -> DestinationState?
  init(
    base: Base,
    id: DestinationState.ID,
    toDestinationState: @escaping (State) -> DestinationState?
  ) {
    self.base = base
    self.id = id
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
  var isInvalid: Bool { state.wrappedValue.flatMap(toDestinationState)?.id != id || base.isInvalid }
  var effectCancellables: [UUID: AnyCancellable] { base.effectCancellables }
}
