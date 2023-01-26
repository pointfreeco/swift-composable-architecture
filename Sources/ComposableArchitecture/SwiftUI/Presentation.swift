@_spi(Reflection) import CasePaths
import SwiftUI

// TODO: `@dynamicMemberLookup`? `Sendable where State: Sendable`
// TODO: copy-on-write box better than indirect enum?
@propertyWrapper
public enum PresentationState<State> {
  case dismissed
  indirect case presented(id: AnyHashable, State)

  public init(wrappedValue: State? = nil) {
    self =
      wrappedValue
      .map { .presented(id: DependencyValues._current.navigationID.next(), $0) }
      ?? .dismissed
  }

  public init(projectedValue: Self) {
    self = projectedValue
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
      // TODO: Do we need similar for the navigation APIs?
      // TODO: Should we _always_ reuse the `id` when value is non-nil, even when enum tags differ?
      guard
        let newValue = newValue,
        case let .presented(id, oldValue) = self,
        enumTag(oldValue) == enumTag(newValue)
      else {
        self = .init(wrappedValue: newValue)
        return
      }

      self = .presented(id: id, newValue)

      // TODO: Should we add state.$destination.present(...) for explicitly re-presenting new ID?
      // TODO: Should we do the following instead (we used to)?
      //self = .init(wrappedValue: newValue)
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
//extension PresentationState: CustomReflectable {
//  public var customMirror: Mirror {
//    Mirror(reflecting: self.wrappedValue as Any)
//  }
//}

public enum PresentationAction<State, Action> {
  case dismiss
  // NB: sending present(id, nil) from the view means let the reducer hydrate state
  case present(id: AnyHashable = DependencyValues._current.uuid(), State? = nil)
  case presented(Action)

  public static var present: Self { .present() }
}

public func ~= <State, Action, ID: Hashable> (
  lhs: ID, rhs: PresentationAction<State, Action>
) -> Bool {
  guard case .present(AnyHashable(lhs), _) = rhs else { return false }
  return true
}

public typealias PresentationActionOf<R: ReducerProtocol> = PresentationAction<R.State, R.Action>

// TODO:
//extension PresentationAction: Decodable where State: Decodable, Action: Decodable {}
//extension PresentationAction: Encodable where State: Encodable, Action: Encodable {}

extension PresentationAction: Equatable where State: Equatable, Action: Equatable {}
extension PresentationAction: Hashable where State: Hashable, Action: Hashable {}

extension ReducerProtocol {
  @inlinable
  public func presentationDestination<Destination: ReducerProtocol>(
    _ toPresentedState: WritableKeyPath<State, PresentationStateOf<Destination>>,
    action toPresentedAction: CasePath<Action, PresentationActionOf<Destination>>,
    @ReducerBuilderOf<Destination> destination: () -> Destination,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> _PresentationDestinationReducer<Self, Destination> {
    _PresentationDestinationReducer(
      presenter: self,
      presented: destination(),
      toPresentedState: toPresentedState,
      toPresentedAction: toPresentedAction,
      file: file,
      fileID: fileID,
      line: line
    )
  }
}

public struct _PresentationDestinationReducer<
  Presenter: ReducerProtocol, Presented: ReducerProtocol
>: ReducerProtocol {
  @usableFromInline
  let presenter: Presenter

  @usableFromInline
  let presented: Presented

  @usableFromInline
  let toPresentedState: WritableKeyPath<Presenter.State, PresentationStateOf<Presented>>

  @usableFromInline
  let toPresentedAction:
    CasePath<
      Presenter.Action, PresentationActionOf<Presented>
    >

  @usableFromInline
  let file: StaticString

  @usableFromInline
  let fileID: StaticString

  @usableFromInline
  let line: UInt

  @usableFromInline
  enum DismissID {}

  @inlinable
  init(
    presenter: Presenter,
    presented: Presented,
    toPresentedState: WritableKeyPath<Presenter.State, PresentationStateOf<Presented>>,
    toPresentedAction: CasePath<Presenter.Action, PresentationActionOf<Presented>>,
    file: StaticString,
    fileID: StaticString,
    line: UInt
  ) {
    self.presenter = presenter
    self.presented = presented
    self.toPresentedState = toPresentedState
    self.toPresentedAction = toPresentedAction
    self.file = file
    self.fileID = fileID
    self.line = line
  }

  @inlinable
  public func reduce(
    into state: inout Presenter.State,
    action: Presenter.Action
  ) -> EffectTask<Presenter.Action> {
    // TODO: explore more performance implications
    //       Doing effect = effect.merge may be faster on the creation side and slower on the run side,
    //       because it creates a lot of nested TaskGroups
    var effects: [EffectTask<Presenter.Action>] = []

    let currentPresentedState = state[keyPath: self.toPresentedState]
    let presentedAction = self.toPresentedAction.extract(from: action)

    // TODO: should we extract id from `presentedAction` at the very beginning, and then wrap
    //       everything below in a `withValue(\.navigationID, id)` ?

    switch presentedAction {
    case let .present(id, .some(presentedState)):
      state[keyPath: self.toPresentedState] = .presented(id: id, presentedState)

    case let .presented(presentedAction):
      if case .presented(let id, var presentedState) = currentPresentedState {
        effects.append(
          self.presented
            .dependency(\.dismiss, DismissEffect { Task.cancel(id: DismissID.self) })
            .dependency(\.navigationID.current, id)
            //            .transformDependency(\.self) {
            //              $0.navigationID.current = id
            //              $0.dismiss = DismissEffect { Task.cancel(id: DismissID.self, navigationID: id) }
            //            }
            .reduce(into: &presentedState, action: presentedAction)
            .map { self.toPresentedAction.embed(.presented($0)) }
            .cancellable(id: id)
        )
        // TODO: Check if presentedState is enum and if current enum tag is alert state

        // TODO: don't create long living effect if we are showing an alert?
        // TODO: handle confirmation dialog too?
        if isAlertState(presentedState) {
          state[keyPath: self.toPresentedState] = .dismissed
        } else {
          state[keyPath: self.toPresentedState] = .presented(id: id, presentedState)
        }
      } else {
        runtimeWarn(
          """
          A "presentationDestination" at "\(self.fileID):\(self.line)" received a destination \
          action when destination state was absent. …

            Action:
              \(debugCaseOutput(action))

          This is generally considered an application logic error, and can happen for a few \
          reasons:

          • A parent reducer set destination state to "nil" before this reducer ran. This reducer \
          must run before any other reducer sets destination state to "nil". This ensures that \
          destination reducers can handle their actions while their state is still present.

          • This action was sent to the store while destination state was "nil". Make sure that \
          actions for this reducer can only be sent from a view store when state is present, or \
          from effects that start from this reducer. In SwiftUI applications, use a Composable \
          Architecture view modifier like "sheet(store:…)".
          """,
          file: self.file,
          line: self.line
        )
        return .none
      }

    case .present(_, .none), .dismiss, .none:
      break
    }

    effects.append(self.presenter.reduce(into: &state, action: action))

    if case .dismiss = presentedAction, case let .presented(id, _) = currentPresentedState {
      state[keyPath: self.toPresentedState].wrappedValue = nil
      effects.append(.cancel(id: id))
    } else if case let .presented(id, _) = currentPresentedState,
      state[keyPath: self.toPresentedState].id != id
    {
      effects.append(.cancel(id: id))
    }

    let updatedPresentedState = state[keyPath: self.toPresentedState] // TODO: write tests
    if
      let id = updatedPresentedState.id,
      id != currentPresentedState.id,
      // NB: Don't start lifecycle effect for alerts
      //     TODO: handle confirmation dialogs too
      updatedPresentedState.wrappedValue.map(isAlertState) != true
    {
      effects.append(
        .run { send in
          do {
            try await withDependencies {
              $0.navigationID.current = id
            } operation: {
              try await withTaskCancellation(id: DismissID.self) {
                try await Task.never()
              }
            }
          } catch is CancellationError {
            await send(self.toPresentedAction.embed(.dismiss))
          }
        }
        .cancellable(id: id)
      )
    }

    return .merge(effects)
  }
}

extension View {
  @available(iOS 14, tvOS 14, watchOS 7, *)
  @available(macOS, unavailable)
  public func fullScreenCover<State, Action, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<State, Action>>,
    @ViewBuilder content: @escaping (Store<State, Action>) -> Content
  ) -> some View {
    self.fullScreenCover(store: store, state: { $0 }, action: { $0 }, content: content)
  }

  @available(iOS 14, tvOS 14, watchOS 7, *)
  @available(macOS, unavailable)
  public func fullScreenCover<State, Action, DestinationState, DestinationAction, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<State, Action>>,
    state toDestinationState: @escaping (State) -> DestinationState?,
    action fromDestinationAction: @escaping (DestinationAction) -> Action,
    @ViewBuilder content: @escaping (Store<DestinationState, DestinationAction>) -> Content
  ) -> some View {
    WithViewStore(store, removeDuplicates: { $0.id == $1.id }) { viewStore in
      self.fullScreenCover(
        item: viewStore.binding(
          get: { Item(destinations: $0, destination: toDestinationState) }, send: .dismiss
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
    store: Store<PresentationState<State>, PresentationAction<State, Action>>,
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
    store: Store<PresentationState<State>, PresentationAction<State, Action>>,
    state toDestinationState: @escaping (State) -> DestinationState?,
    action fromDestinationAction: @escaping (DestinationAction) -> Action,
    attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds),
    arrowEdge: Edge = .top,
    @ViewBuilder content: @escaping (Store<DestinationState, DestinationAction>) -> Content
  ) -> some View {
    WithViewStore(store, removeDuplicates: { $0.id == $1.id }) { viewStore in
      self.popover(
        item: viewStore.binding(
          get: { Item(destinations: $0, destination: toDestinationState) }, send: .dismiss
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

  public func sheet<State, Action, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<State, Action>>,
    @ViewBuilder content: @escaping (Store<State, Action>) -> Content
  ) -> some View {
    self.sheet(store: store, state: { $0 }, action: { $0 }, content: content)
  }

  public func sheet<State, Action, DestinationState, DestinationAction, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<State, Action>>,
    state toDestinationState: @escaping (State) -> DestinationState?,
    action fromDestinationAction: @escaping (DestinationAction) -> Action,
    @ViewBuilder content: @escaping (Store<DestinationState, DestinationAction>) -> Content
  ) -> some View {
    WithViewStore(store, removeDuplicates: { $0.id == $1.id }) { viewStore in
      self.sheet(
        item: viewStore.binding(
          get: { Item(destinations: $0, destination: toDestinationState) }, send: .dismiss
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

  // TODO: kinda confusing to have navigationDestination defined for both PresentationState
  //       and NavigationState.
  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  public func navigationDestination<State, Action, Destination: View>(
    store: Store<PresentationState<State>, PresentationAction<State, Action>>,
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

// TODO: needed?
//private func areDestinationsEqual<State>(
//  _ lhs: PresentationState<State>,
//  _ rhs: PresentationState<State>
//) -> Bool {
//  lhs.id == rhs.id
//}

private struct Item: Identifiable {
  let id: AnyHashable

  init?<Destination, Destinations>(
    destinations: PresentationState<Destinations>,
    destination toDestination: (Destinations) -> Destination?
  ) {
    guard
      case let .presented(id, destinations) = destinations,
      toDestination(destinations) != nil
    else { return nil }

    self.id = id
  }
}

// TODO: worth it?
public struct PresentedView<
  State,
  Action,
  DestinationState,
  DestinationAction,
  Destination: View,
  Dismissed: View
>: View {
  let store: Store<PresentationState<State>, PresentationAction<State, Action>>
  let toDestinationState: (State) -> DestinationState?
  let fromDestinationAction: (DestinationAction) -> Action
  let destination: (Store<DestinationState, DestinationAction>) -> Destination
  let dismissed: Dismissed

  public init( 
    _ store: Store<PresentationState<State>, PresentationAction<State, Action>>,
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
    _ store: Store<PresentationState<State>, PresentationAction<State, Action>>,
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

@usableFromInline protocol _AlertState {}

extension AlertState: _AlertState {}

@usableFromInline
func isAlertState<T>(_ state: T) -> Bool {
  if state is _AlertState {
    return true
  } else if let metadata = EnumMetadata(type(of: state)) {
    return metadata.associatedValueType(forTag: metadata.tag(of: state)) is _AlertState.Type
  } else {
    return false
  }
}
