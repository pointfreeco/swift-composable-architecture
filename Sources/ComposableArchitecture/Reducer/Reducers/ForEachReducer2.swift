import OrderedCollections


extension Reducer {
  @inlinable
  @warn_unqualified_access
  public func forEach2<ElementState, ElementAction, ID: Hashable, Element: Reducer>(
    _ toElementsState: WritableKeyPath<State, IdentifiedArray<ID, ElementState>>,
    action toElementAction: CaseKeyPath<Action, IdentifiedAction<ID, ElementAction>>,
    @ReducerBuilder<ElementState, ElementAction> element: () -> Element,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> _ForEachReducer2<Self, ID, Element>
  where ElementState == Element.State, ElementAction == Element.Action {
    _ForEachReducer2(
      parent: self,
      toElementsState: toElementsState,
      toElementAction: toElementAction,//.appending(path: \.element),
      element: element(),
      fileID: fileID,
      line: line
    )
  }
}

public struct _ForEachReducer2<
  Parent: Reducer, ID: Hashable, Element: Reducer
>: Reducer
where
  Parent.State: ObservableState,
  Parent.Action: CasePathable
{
  @usableFromInline
  let parent: Parent

  @usableFromInline
  let toElementsState: WritableKeyPath<Parent.State, IdentifiedArray<ID, Element.State>>

  @usableFromInline
  let toElementAction: CaseKeyPath<Parent.Action, IdentifiedAction<ID, Element.Action>>

  @usableFromInline
  let element: Element

  @usableFromInline
  let fileID: StaticString

  @usableFromInline
  let line: UInt

  @Dependency(\.navigationIDPath) var navigationIDPath

  @usableFromInline
  init(
    parent: Parent,
    toElementsState: WritableKeyPath<Parent.State, IdentifiedArray<ID, Element.State>>,
    toElementAction: CaseKeyPath<Parent.Action, IdentifiedAction<ID, Element.Action>>,
    element: Element,
    fileID: StaticString,
    line: UInt
  ) {
    self.parent = parent
    self.toElementsState = toElementsState
    self.toElementAction = toElementAction
    self.element = element
    self.fileID = fileID
    self.line = line
  }

  public func _reduce(into store: StoreOf<Parent>, action: Parent.Action) {
    if 
      case let .element(id: id, action: elementAction) = action[case: self.toElementAction]
    {
      if store.state[keyPath: self.toElementsState][id: id] == nil {
        // TODO: runtime warn
      } else if let childStore = store.scope(
        state: self.toElementsState.appending(path: \.[id: id]),
        action: self.toElementAction.appending(path: \.[id: id])
      ) {
        self.element._reduce(into: childStore, action: elementAction)
      }
    }

    self.parent._reduce(into: store, action: action)
  }

//  public func reduce(
//    into state: inout Parent.State, action: Parent.Action
//  ) -> Effect<Parent.Action> {
//    let elementEffects = self.reduceForEach(into: &state, action: action)
//
//    let idsBefore = state[keyPath: self.toElementsState].ids
//    let parentEffects = self.parent.reduce(into: &state, action: action)
//    let idsAfter = state[keyPath: self.toElementsState].ids
//
//    let elementCancelEffects: Effect<Parent.Action> =
//    areOrderedSetsDuplicates(idsBefore, idsAfter)
//    ? .none
//    : .merge(
//      idsBefore.subtracting(idsAfter).map {
//        ._cancel(
//          id: NavigationID(id: $0, keyPath: self.toElementsState),
//          navigationID: self.navigationIDPath
//        )
//      }
//    )
//
//    return .merge(
//      elementEffects,
//      parentEffects,
//      elementCancelEffects
//    )
//  }

//  func reduceForEach(
//    into state: inout Parent.State, action: Parent.Action
//  ) -> Effect<Parent.Action> {
//    guard let (id, elementAction) = action[case: self.toElementAction] else { return .none }
//    if state[keyPath: self.toElementsState][id: id] == nil {
//      runtimeWarn(
//        """
//        A "forEach" at "\(self.fileID):\(self.line)" received an action for a missing element. …
//
//          Action:
//            \(debugCaseOutput(action))
//
//        This is generally considered an application logic error, and can happen for a few reasons:
//
//        • A parent reducer removed an element with this ID before this reducer ran. This reducer \
//        must run before any other reducer removes an element, which ensures that element reducers \
//        can handle their actions while their state is still available.
//
//        • An in-flight effect emitted this action when state contained no element at this ID. \
//        While it may be perfectly reasonable to ignore this action, consider canceling the \
//        associated effect before an element is removed, especially if it is a long-living effect.
//
//        • This action was sent to the store while its state contained no element at this ID. To \
//        fix this make sure that actions for this reducer can only be sent from a view store when \
//        its state contains an element at this id. In SwiftUI applications, use "ForEachStore".
//        """
//      )
//      return .none
//    }
//    let navigationID = NavigationID(id: id, keyPath: self.toElementsState)
//    let elementNavigationID = self.navigationIDPath.appending(navigationID)
//    return self.element
//      .dependency(\.navigationIDPath, elementNavigationID)
//      .reduce(into: &state[keyPath: self.toElementsState][id: id]!, action: elementAction)
//      .map { self.toElementAction((id, $0)) }
//      ._cancellable(id: navigationID, navigationIDPath: self.navigationIDPath)
//  }
}
