import SwiftUI

// TODO: `@dynamicMemberLookup`? `Sendable where State: Sendable`
@propertyWrapper
public enum PresentationState<State> {
  case dismissed
  indirect case presented(id: AnyHashable, State)

  public mutating func present(_ value: State) {
    self.wrappedValue = value
  }

  public mutating func dismiss() {
    self = .dismissed
  }

  public init(wrappedValue: State?) {
    self = wrappedValue.map { .presented(id: UUID(), $0) } ?? .dismissed
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
      self = newValue.map { .presented(id: UUID(), $0) } ?? .dismissed
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

extension PresentationState: CustomReflectable {
  public var customMirror: Mirror {
    Mirror(reflecting: self.wrappedValue as Any)
  }
}

public enum PresentationAction<State, Action> {
  case present(State?)
  case presented(Action)
  case dismiss

  public static var present: Self { .present(nil) }
}

extension PresentationAction: Decodable where State: Decodable, Action: Decodable {}
extension PresentationAction: Encodable where State: Encodable, Action: Encodable {}

extension PresentationAction: Equatable where State: Equatable, Action: Equatable {}
extension PresentationAction: Hashable where State: Hashable, Action: Hashable {}

extension ReducerProtocol {
  public func presents<Destination: ReducerProtocol>(
    state: WritableKeyPath<State, PresentationState<Destination.State>>,
    action: CasePath<Action, PresentationAction<Destination.State, Destination.Action>>,
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
  let toPresentedState: WritableKeyPath<Presenter.State, PresentationState<Presented.State>>
  let toPresentedAction:
    CasePath<
      Presenter.Action, PresentationAction<Presented.State, Presented.Action>
    >

  public func reduce(
    into state: inout Presenter.State, action: Presenter.Action
  ) -> Effect<Presenter.Action, Never> {
    var effects: [Effect<Presenter.Action, Never>] = []

    let presentedState = state[keyPath: toPresentedState]
    let presentedAction = toPresentedAction.extract(from: action)

    switch toPresentedAction.extract(from: action) {
    case let .present(.some(presentedState)):
      state[keyPath: toPresentedState].wrappedValue = presentedState

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

    case .present(.none), .dismiss, .none:
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
  @available(iOS 14, tvOS 14, watchOS 7, *)
  @available(macOS, unavailable)
  public func fullScreenCover<State, Action, Content>(
    store: Store<PresentationState<State>, PresentationAction<State, Action>>,
    @ViewBuilder content: @escaping (Store<State, Action>) -> Content
  ) -> some View
  where Content: View {
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

  @available(tvOS, unavailable)
  public func popover<State, Action, Content>(
    store: Store<PresentationState<State>, PresentationAction<State, Action>>,
    attachmentAnchor: PopoverAttachmentAnchor,
    arrowEdge: Edge,
    @ViewBuilder content: @escaping (Store<State, Action>) -> Content
  ) -> some View
  where Content: View {
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

  public func sheet<State, Action, Content>(
    store: Store<PresentationState<State>, PresentationAction<State, Action>>,
    @ViewBuilder content: @escaping (Store<State, Action>) -> Content
  ) -> some View
  where Content: View {
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
}
