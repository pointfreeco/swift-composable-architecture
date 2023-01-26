@_spi(Reflection) import CasePaths
import SwiftUI

@propertyWrapper
public struct PresentationState<State> {
  private var boxedValue: [State]

  @Dependency(\.navigationID) var navigationID

  public init(wrappedValue: State? = nil) {
    self.boxedValue = wrappedValue.map { [$0] } ?? []
  }

  public init(projectedValue: Self) {
    self = projectedValue
  }

  public var wrappedValue: State? {
    _read { yield self.boxedValue.first }
    _modify {
      var state = self.boxedValue.first
      yield &state
      switch (state, self.boxedValue.isEmpty) {
      case (nil, true):
        return
      case (nil, false):
        self.boxedValue = []
      case let (.some(state), true):
        self.boxedValue.insert(state, at: 0)
      case let (.some(state), false):
        self.boxedValue[0] = state
      }
    }
    set {
      switch (newValue, self.boxedValue.isEmpty) {
      case (nil, true):
        return
      case (nil, false):
        self.boxedValue = []
      case let (.some(state), true):
        self.boxedValue.insert(state, at: 0)
      case let (.some(state), false):
        self.boxedValue[0] = state
      }
    }
  }

  public var projectedValue: Self {
    _read { yield self }
    _modify { yield &self }
  }

  public var identifiedValue: (id: NavigationID, state: State)? {
    self.wrappedValue.map { (self.navigationID.append($0), $0) }
  }

  public var id: NavigationID? {
    self.identifiedValue?.id
  }
}

public typealias PresentationStateOf<R: ReducerProtocol> = PresentationState<R.State>

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

extension PresentationState: CustomReflectable {
  public var customMirror: Mirror {
    Mirror(reflecting: self.wrappedValue as Any)
  }
}

public enum PresentationAction<Action> {
  case dismiss
  case presented(Action)
}

public typealias PresentationActionOf<R: ReducerProtocol> = PresentationAction<R.Action>

extension PresentationAction: Equatable where Action: Equatable {}
extension PresentationAction: Hashable where Action: Hashable {}

extension PresentationAction: Decodable where Action: Decodable {}
extension PresentationAction: Encodable where Action: Encodable {}

extension ReducerProtocol {
  @inlinable
  public func presentationDestination<
    DestinationState, DestinationAction, Destination: ReducerProtocol
  >(
    _ toPresentedState: WritableKeyPath<State, PresentationState<DestinationState>>,
    action toPresentedAction: CasePath<Action, PresentationAction<DestinationAction>>,
    @ReducerBuilder<DestinationState, DestinationAction> destination: () -> Destination,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> _PresentationDestinationReducer<Self, Destination>
  where DestinationState == Destination.State, DestinationAction == Destination.Action {
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
    let presentationState = state[keyPath: self.toPresentedState]
    let presentationAction = self.toPresentedAction.extract(from: action)
    var effects: EffectTask<Presenter.Action> = .none

    if case let .some(.presented(presentedAction)) = presentationAction {
      switch presentationState.identifiedValue {
      case .some((let id, var presentedState)):
        defer { state[keyPath: self.toPresentedState].wrappedValue = presentedState }
        effects = effects.merge(
          with: self.presented
            .dependency(\.navigationID, id)
            .reduce(into: &presentedState, action: presentedAction)
            .map { self.toPresentedAction.embed(.presented($0)) }
            .cancellable(id: id)
        )
      case .none:
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
      }
    }

    effects = effects.merge(
      with: self.presenter.reduce(into: &state, action: action)
    )

    if case .some(.dismiss) = presentationAction {
      if state[keyPath: self.toPresentedState].wrappedValue == nil {
        // TODO: Finesse
        runtimeWarn(
          """
          A "presentationDestination" at "\(self.fileID):\(self.line)" received a dismissal \
          action when destination state was already absent.
          """,
          file: self.file,
          line: self.line
        )
      } else {
        state[keyPath: self.toPresentedState].wrappedValue = nil
      }
    }

    if
      let (id, _) = presentationState.identifiedValue,
      state[keyPath: self.toPresentedState].identifiedValue?.id != id
    {
      effects = effects.merge(
        with: .cancel(id: id)
      )
    }

    if
      state[keyPath: self.toPresentedState].wrappedValue.map(isDialogState) == true,
      case .some(.presented) = presentationAction
    {
      state[keyPath: self.toPresentedState].wrappedValue = nil
    }

    return effects

//    switch presentedAction {
//    case let .presented(presentedAction):
//      if var presentedState = currentPresentedState.wrappedValue {
//        let id = PresentationState.ID(presentedState)
//        effects.append(
//          self.presented
//            .dependency(\.dismiss, DismissEffect { Task.cancel(id: DismissID.self) })
//            .dependency(\.navigationID, id)
//            .reduce(into: &presentedState, action: presentedAction)
//            .map { self.toPresentedAction.embed(.presented($0)) }
//            .cancellable(id: id)
//        )
//
//        state[keyPath: self.toPresentedState].wrappedValue =
//          isDialogState(presentedState)
//          ? nil
//          : presentedState
//      } else {
//        runtimeWarn(
//          """
//          A "presentationDestination" at "\(self.fileID):\(self.line)" received a destination \
//          action when destination state was absent. …
//
//            Action:
//              \(debugCaseOutput(action))
//
//          This is generally considered an application logic error, and can happen for a few \
//          reasons:
//
//          • A parent reducer set destination state to "nil" before this reducer ran. This reducer \
//          must run before any other reducer sets destination state to "nil". This ensures that \
//          destination reducers can handle their actions while their state is still present.
//
//          • This action was sent to the store while destination state was "nil". Make sure that \
//          actions for this reducer can only be sent from a view store when state is present, or \
//          from effects that start from this reducer. In SwiftUI applications, use a Composable \
//          Architecture view modifier like "sheet(store:…)".
//          """,
//          file: self.file,
//          line: self.line
//        )
//        return .none
//      }
//
//    case .dismiss, .none:
//      break
//    }
//
//    effects.append(self.presenter.reduce(into: &state, action: action))
//
//    if case .dismiss = presentedAction, let id = currentPresentedState.id {
//      state[keyPath: self.toPresentedState].wrappedValue = nil
//      effects.append(.cancel(id: id))
//    } else if let id = currentPresentedState.id,
//      state[keyPath: self.toPresentedState].id != id
//    {
//      effects.append(.cancel(id: id))
//    }
//
//    let tmp = state[keyPath: self.toPresentedState]  // TODO: better name, write tests
//    if let id = tmp.id,
//      id != currentPresentedState.id,
//      // NB: Don't start lifecycle effect for alerts
//      //     TODO: handle confirmation dialogs too
//      tmp.wrappedValue.map(isDialogState) != true
//    {
//      effects.append(
//        .run { send in
//          do {
//            try await withDependencies {
//              $0.navigationID.current = id
//            } operation: {
//              try await withTaskCancellation(id: DismissID.self) {
//                try await Task.never()
//              }
//            }
//          } catch is CancellationError {
//            await send(self.toPresentedAction.embed(.dismiss))
//          }
//        }
//        .cancellable(id: id)
//      )
//    }
//
//    return .merge(effects)
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
    WithViewStore(store, removeDuplicates: { $0.id == $1.id }) { viewStore in
      self.fullScreenCover(
        item: viewStore.binding(
          get: { $0.id }, send: .dismiss
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
    WithViewStore(store, removeDuplicates: { $0.id == $1.id }) { viewStore in
      self.popover(item: viewStore.binding(get: { $0.id }, send: .dismiss)) { _ in
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
    WithViewStore(store, removeDuplicates: { $0.id == $1.id }) { viewStore in
      self.sheet(item: viewStore.binding(get: { $0.id }, send: .dismiss)) { _ in
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
      store.scope(state: { $0.wrappedValue.flatMap(toDestinationState) != nil })
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

// TODO: worth it?
public struct PresentedView<
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

@usableFromInline protocol _DialogState {}

extension AlertState: _DialogState {}

@available(iOS 13, macOS 12, tvOS 13, watchOS 6, *)
extension ConfirmationDialogState: _DialogState {}

@usableFromInline
func isDialogState<T>(_ state: T) -> Bool {
  if state is _DialogState {
    return true
  } else if let metadata = EnumMetadata(type(of: state)) {
    return metadata.associatedValueType(forTag: metadata.tag(of: state)) is _DialogState.Type
  } else {
    return false
  }
}
