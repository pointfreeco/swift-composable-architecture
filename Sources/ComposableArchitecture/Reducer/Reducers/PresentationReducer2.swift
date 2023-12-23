@_spi(Reflection) import CasePaths
import Combine

extension Reducer {
  @warn_unqualified_access
  @inlinable
  public func ifLet2<DestinationState, DestinationAction, Destination: Reducer>(
    _ toPresentationState: WritableKeyPath<State, DestinationState?>,
    action toPresentationAction: CaseKeyPath<Action, PresentationAction<DestinationAction>>,
    @ReducerBuilder<DestinationState, DestinationAction> destination: () -> Destination,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> _PresentationReducer2<Self, Destination>
  where Destination.State == DestinationState, Destination.Action == DestinationAction {
    _PresentationReducer2(
      base: self,
      toPresentationState: toPresentationState,
      toPresentationAction: toPresentationAction,
      destination: destination(),
      fileID: fileID,
      line: line
    )
  }
}

public struct _PresentationReducer2<Base: Reducer, Destination: Reducer>: Reducer
where Base.Action: CasePathable
{
  @usableFromInline let base: Base
  @usableFromInline let toPresentationState:
    WritableKeyPath<Base.State, Destination.State?>
  @usableFromInline let toPresentationAction:
    CaseKeyPath<Base.Action, PresentationAction<Destination.Action>>
  @usableFromInline let destination: Destination
  @usableFromInline let fileID: StaticString
  @usableFromInline let line: UInt

  @Dependency(\.navigationIDPath) var navigationIDPath

  @usableFromInline
  init(
    base: Base,
    toPresentationState: WritableKeyPath<Base.State, Destination.State?>,
    toPresentationAction: CaseKeyPath<Base.Action, PresentationAction<Destination.Action>>,
    destination: Destination,
    fileID: StaticString,
    line: UInt
  ) {
    self.base = base
    self.toPresentationState = toPresentationState
    self.toPresentationAction = toPresentationAction
    self.destination = destination
    self.fileID = fileID
    self.line = line
  }

  public func _reduce(into store: Store<Base.State, Base.Action>, action: Base.Action) {
    if
      let presentationAction = action[case: self.toPresentationAction],
      case let .presented(destinationAction) = presentationAction,
      let destinationStore = store.scope(
        state: self.toPresentationState,
        action: self.toPresentationAction.appending(path: \.presented)
      )
    {
      self.destination._reduce(into: destinationStore, action: destinationAction)
    }

    self.base._reduce(into: store, action: action)
    if store.currentState[keyPath: self.toPresentationState] == nil {
      store.children[
        ScopeID(
          state: self.toPresentationState.appending(path: \.!),
          action: self.toPresentationAction.appending(path: \.presented)
        )
      ] = nil
    }
  }

//  public func reduce(into state: inout Base.State, action: Base.Action) -> Effect<Base.Action> {
//    let initialPresentationState = state[keyPath: self.toPresentationState]
//    let presentationAction = self.toPresentationAction.extract(from: action)
//
//    let destinationEffects: Effect<Base.Action>
//    let baseEffects: Effect<Base.Action>
//
//    switch (initialPresentationState.wrappedValue, presentationAction) {
//    case let (.some(destinationState), .some(.dismiss)):
//      destinationEffects = .none
//      baseEffects = self.base.reduce(into: &state, action: action)
//      if self.navigationIDPath(for: destinationState)
//        == state[keyPath: self.toPresentationState].wrappedValue.map(self.navigationIDPath(for:))
//      {
//        state[keyPath: self.toPresentationState].wrappedValue = nil
//      }
//
//    case let (.some(destinationState), .some(.presented(destinationAction))):
//      let destinationNavigationIDPath = self.navigationIDPath(for: destinationState)
//      destinationEffects = self.destination
//        .dependency(
//          \.dismiss,
//          DismissEffect { @MainActor in
//            Task._cancel(id: PresentationDismissID(), navigationID: destinationNavigationIDPath)
//          }
//        )
//        .dependency(\.navigationIDPath, destinationNavigationIDPath)
//        .reduce(
//          into: &state[keyPath: self.toPresentationState].wrappedValue!, action: destinationAction
//        )
//        .map { self.toPresentationAction.embed(.presented($0)) }
//        ._cancellable(navigationIDPath: destinationNavigationIDPath)
//      baseEffects = self.base.reduce(into: &state, action: action)
//      if let ephemeralType = ephemeralType(of: destinationState),
//        destinationNavigationIDPath
//          == state[keyPath: self.toPresentationState].wrappedValue.map(self.navigationIDPath(for:)),
//        ephemeralType.canSend(destinationAction)
//      {
//        state[keyPath: self.toPresentationState].wrappedValue = nil
//      }
//
//    case (.none, .none), (.some, .none):
//      destinationEffects = .none
//      baseEffects = self.base.reduce(into: &state, action: action)
//
//    case (.none, .some):
//      runtimeWarn(
//        """
//        An "ifLet" at "\(self.fileID):\(self.line)" received a presentation action when \
//        destination state was absent. …
//
//          Action:
//            \(debugCaseOutput(action))
//
//        This is generally considered an application logic error, and can happen for a few \
//        reasons:
//
//        • A parent reducer set destination state to "nil" before this reducer ran. This reducer \
//        must run before any other reducer sets destination state to "nil". This ensures that \
//        destination reducers can handle their actions while their state is still present.
//
//        • This action was sent to the store while destination state was "nil". Make sure that \
//        actions for this reducer can only be sent from a view store when state is present, or \
//        from effects that start from this reducer. In SwiftUI applications, use a Composable \
//        Architecture view modifier like "sheet(store:…)".
//        """
//      )
//      destinationEffects = .none
//      baseEffects = self.base.reduce(into: &state, action: action)
//    }
//
//    let presentationIdentityChanged =
//      initialPresentationState.presentedID
//      != state[keyPath: self.toPresentationState].wrappedValue.map(self.navigationIDPath(for:))
//
//    let dismissEffects: Effect<Base.Action>
//    if presentationIdentityChanged,
//      let presentedPath = initialPresentationState.presentedID,
//      initialPresentationState.wrappedValue.map({
//        self.navigationIDPath(for: $0) == presentedPath && !isEphemeral($0)
//      })
//        ?? true
//    {
//      dismissEffects = ._cancel(navigationID: presentedPath)
//    } else {
//      dismissEffects = .none
//    }
//
//    if presentationIdentityChanged, state[keyPath: self.toPresentationState].wrappedValue == nil {
//      state[keyPath: self.toPresentationState].presentedID = nil
//    }
//
//    let presentEffects: Effect<Base.Action>
//    if presentationIdentityChanged || state[keyPath: self.toPresentationState].presentedID == nil,
//      let presentationState = state[keyPath: self.toPresentationState].wrappedValue,
//      !isEphemeral(presentationState)
//    {
//      let presentationDestinationID = self.navigationIDPath(for: presentationState)
//      state[keyPath: self.toPresentationState].presentedID = presentationDestinationID
//      presentEffects = .concatenate(
//        .publisher { Empty(completeImmediately: false) }
//          ._cancellable(id: PresentationDismissID(), navigationIDPath: presentationDestinationID),
//        .publisher { Just(self.toPresentationAction.embed(.dismiss)) }
//      )
//      ._cancellable(navigationIDPath: presentationDestinationID)
//      ._cancellable(id: OnFirstAppearID(), navigationIDPath: .init())
//    } else {
//      presentEffects = .none
//    }
//
//    return .merge(
//      destinationEffects,
//      baseEffects,
//      dismissEffects,
//      presentEffects
//    )
//  }
}
