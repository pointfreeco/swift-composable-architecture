import SwiftUI

// TODO: `@dynamicMemberLookup`? `Sendable where State: Sendable`
@propertyWrapper
public enum PresentationState<State> {
  case dismissed
  indirect case presented(id: AnyHashable, State)

  public init(wrappedValue: State? = nil) {
    self =
      wrappedValue
      .map { .presented(id: DependencyValues.current.navigationID.next(), $0) }
      ?? .dismissed
  }

  public var wrappedValue: State? {
    _read {
      switch self {
      case .dismissed:
        yield nil
      case let .presented(_, state):
        yield state
      }
    }
    _modify {
      switch self {
      case .dismissed:
        var state: State? = nil
        yield &state
      case let .presented(id, state):
        var state: State! = state
        yield &state
        self = .presented(id: id, state)
      }
    }
    set {
      self = .init(wrappedValue: newValue)
    }
  }

  public var projectedValue: Self {
    _read { yield self }
    _modify { yield &self }
  }

  public var id: AnyHashable? {
    switch self {
    case .dismissed:
      return nil
    case let .presented(id, _):
      return id
    }
  }
}

public typealias PresentationStateOf<R: ReducerProtocol> = PresentationState<R.State>

// TODO: Should ID be encodable/decodable ever?
extension PresentationState: Decodable where State: Decodable {
  public init(from decoder: Decoder) throws {
    self.init(wrappedValue: try State?(from: decoder))
  }
}
extension PresentationState: Encodable where State: Encodable {
  public func encode(to encoder: Encoder) throws {
    try self.wrappedValue?.encode(to: encoder)
  }
}

extension PresentationState: Equatable where State: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.wrappedValue == rhs.wrappedValue
  }
}
extension PresentationState: Hashable where State: Hashable {
  public func hash(into hasher: inout Hasher) {
    self.wrappedValue.hash(into: &hasher)
  }
}

// TODO: Should ID clutter custom dump logs?
extension PresentationState: CustomReflectable {
  public var customMirror: Mirror {
    Mirror(reflecting: self.wrappedValue as Any)
  }
}

public enum PresentationAction<State, Action> {
  case present(id: AnyHashable = DependencyValues.current.uuid(), State? = nil)
  case presented(Action)
  case dismiss

  public static var present: Self { .present() }
}

public typealias PresentationActionOf<R: ReducerProtocol> = PresentationAction<R.State, R.Action>

// TODO:
//extension PresentationAction: Decodable where State: Decodable, Action: Decodable {}
//extension PresentationAction: Encodable where State: Encodable, Action: Encodable {}

extension PresentationAction: Equatable where State: Equatable, Action: Equatable {}
extension PresentationAction: Hashable where State: Hashable, Action: Hashable {}

extension ReducerProtocol {
  public func presentationDestination<Destination: ReducerProtocol>(
    state: WritableKeyPath<State, PresentationStateOf<Destination>>,
    action: CasePath<Action, PresentationActionOf<Destination>>,
    @ReducerBuilderOf<Destination> destination: () -> Destination
  ) -> PresentationReducer<Self, Destination> {
    PresentationReducer(
      presenter: self,
      presented: destination(),
      toPresentedState: state,
      toPresentedAction: action
    )
  }
}

public struct PresentationReducer<
  Presenter: ReducerProtocol, Presented: ReducerProtocol
>: ReducerProtocol {
  let presenter: Presenter
  let presented: Presented
  let toPresentedState: WritableKeyPath<Presenter.State, PresentationStateOf<Presented>>
  let toPresentedAction:
    CasePath<
      Presenter.Action, PresentationActionOf<Presented>
    >

  public func reduce(
    into state: inout Presenter.State, action: Presenter.Action
  ) -> Effect<Presenter.Action, Never> {
    var effects: [Effect<Presenter.Action, Never>] = []

    let presentedState = state[keyPath: toPresentedState]
    let presentedAction = toPresentedAction.extract(from: action)

    switch presentedAction {
    case let .present(id, .some(presentedState)):
      state[keyPath: toPresentedState] = .presented(id: id, presentedState)

    case let .presented(presentedAction):
      if case .presented(let id, var presentedState) = presentedState {
        defer { state[keyPath: toPresentedState] = .presented(id: id, presentedState) }
        effects.append(
          self.presented
            .dependency(\.navigationID.current, id)
            .reduce(into: &presentedState, action: presentedAction)
            .map { toPresentedAction.embed(.presented($0)) }
            .cancellable(id: id)
        )
      }

    case .present(_, .none), .dismiss, .none:
      break
    }

    effects.append(self.presenter.reduce(into: &state, action: action))

    if case .dismiss = presentedAction, case let .presented(id, _) = presentedState {
      state[keyPath: toPresentedState].wrappedValue = nil
      effects.append(.cancel(id: id))
    } else if case let .presented(id, _) = presentedState,
      state[keyPath: toPresentedState].id != id
    {
      effects.append(.cancel(id: id))
    }

    return .merge(effects)
  }
}

extension View {
  // TODO: How does `onDismiss:` factor in?
  @available(iOS 14, tvOS 14, watchOS 7, *)
  @available(macOS, unavailable)
  public func fullScreenCover<State, Action, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<State, Action>>,
    @ViewBuilder content: @escaping (Store<State, Action>) -> Content
  ) -> some View {
    WithViewStore(store.scope(state: { $0.wrappedValue != nil })) { viewStore in
      self.fullScreenCover(isPresented: viewStore.binding(send: { $0 ? .present : .dismiss })) {
        IfLetStore(
          store.scope(
            state: returningLastNonNilValue { $0.wrappedValue },
            action: PresentationAction.presented
          ),
          then: content
        )
      }
    }
  }

  // TODO: How does `onDismiss:` factor in?
  @available(iOS 14, tvOS 14, watchOS 7, *)
  @available(macOS, unavailable)
  public func fullScreenCover<State, Action, DestinationState, DestinationAction, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<State, Action>>,
    state toDestinationState: @escaping (State) -> DestinationState?,
    action fromDestinationAction: @escaping (DestinationAction) -> Action,
    @ViewBuilder content: @escaping (Store<DestinationState, DestinationAction>) -> Content
  ) -> some View {
    WithViewStore(
      store.scope(state: { $0.wrappedValue }),
      removeDuplicates: { ($0 != nil) == ($1 != nil) && enumTag($0) == enumTag($1) }
    ) { viewStore in
      self.fullScreenCover(
        item: viewStore.binding(
          get: {
            $0.flatMap { PresentationItem(destinations: $0, destination: toDestinationState) }
          },
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
  public func popover<State, Action, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<State, Action>>,
    attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds),
    arrowEdge: Edge = .top,
    @ViewBuilder content: @escaping (Store<State, Action>) -> Content
  ) -> some View {
    WithViewStore(store.scope(state: { $0.wrappedValue != nil })) { viewStore in
      self.popover(
        isPresented: viewStore.binding(send: { $0 ? .present : .dismiss }),
        attachmentAnchor: attachmentAnchor,
        arrowEdge: arrowEdge
      ) {
        IfLetStore(
          store.scope(
            state: returningLastNonNilValue { $0.wrappedValue },
            action: PresentationAction.presented
          ),
          then: content
        )
      }
    }
  }

  @available(tvOS, unavailable)
  public func popover<State, Action, DestinationState, DestinationAction, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<State, Action>>,
    state toDestinationState: @escaping (State) -> DestinationState?,
    action fromDestinationAction: @escaping (DestinationAction) -> Action,
    attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds),
    arrowEdge: Edge = .top,
    @ViewBuilder content: @escaping (Store<DestinationState, DestinationAction>) -> Content
  ) -> some View {
    WithViewStore(
      store.scope(state: { $0.wrappedValue }),
      removeDuplicates: { ($0 != nil) == ($1 != nil) && enumTag($0) == enumTag($1) }
    ) { viewStore in
      self.popover(
        item: viewStore.binding(
          get: {
            $0.flatMap { PresentationItem(destinations: $0, destination: toDestinationState) }
          },
          send: .dismiss
        ),
        attachmentAnchor: attachmentAnchor,
        arrowEdge: arrowEdge
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

  // TODO: How does `onDismiss:` factor in?
  public func sheet<State, Action, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<State, Action>>,
    @ViewBuilder content: @escaping (Store<State, Action>) -> Content
  ) -> some View {
    WithViewStore(store.scope(state: { $0.wrappedValue != nil })) { viewStore in
      self.sheet(isPresented: viewStore.binding(send: { $0 ? .present : .dismiss })) {
        IfLetStore(
          store.scope(
            state: returningLastNonNilValue { $0.wrappedValue },
            action: PresentationAction.presented
          ),
          then: content
        )
      }
    }
  }

  // TODO: How does `onDismiss:` factor in?
  public func sheet<State, Action, DestinationState, DestinationAction, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<State, Action>>,
    state toDestinationState: @escaping (State) -> DestinationState?,
    action fromDestinationAction: @escaping (DestinationAction) -> Action,
    @ViewBuilder content: @escaping (Store<DestinationState, DestinationAction>) -> Content
  ) -> some View {
    WithViewStore(
      store.scope(state: { $0.wrappedValue }),
      removeDuplicates: { ($0 != nil) == ($1 != nil) && enumTag($0) == enumTag($1) }
    ) { viewStore in
      self.sheet(
        item: viewStore.binding(
          get: {
            $0.flatMap { PresentationItem(destinations: $0, destination: toDestinationState) }
          },
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

  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  public func navigationDestination<State, Action, Destination: View>(
    store: Store<PresentationState<State>, PresentationAction<State, Action>>,
    @ViewBuilder destination: @escaping (Store<State, Action>) -> Destination
  ) -> some View {
    WithViewStore(store.scope(state: { $0.wrappedValue != nil })) { viewStore in
      self.navigationDestination(
        isPresented: viewStore.binding(send: { $0 ? .present : .dismiss })
      ) {
        IfLetStore(
          store.scope(
            state: returningLastNonNilValue { $0.wrappedValue },
            action: PresentationAction.presented
          ),
          then: destination
        )
      }
    }
  }

  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  public func navigationDestination<
    State, Action, DestinationState, DestinationAction, Destination: View
  >(
    store: Store<PresentationState<State>, PresentationAction<State, Action>>,
    state toDestinationState: @escaping (State) -> DestinationState?,
    action fromDestinationAction: @escaping (DestinationAction) -> Action,
    @ViewBuilder destination: @escaping (Store<DestinationState, DestinationAction>) -> Destination
  ) -> some View {
    WithViewStore(
      store.scope(state: { $0.wrappedValue.flatMap(toDestinationState) != nil })
    ) { viewStore in
      self.navigationDestination(
        isPresented: viewStore.binding(send: { $0 ? .present : .dismiss })
      ) {
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

private struct PresentationItem: Identifiable {
  struct ID: Hashable {
    let tag: UInt32?
    let discriminator: ObjectIdentifier
  }

  let id: ID

  init?<Destination, Destinations>(
    destinations: Destinations,
    destination toDestination: (Destinations) -> Destination?
  ) {
    guard let destination = toDestination(destinations) else { return nil }
    self.id = ID(
      tag: enumTag(destinations),
      discriminator: ObjectIdentifier(type(of: destination))
    )
  }
}
