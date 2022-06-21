extension ReducerProtocol {
  @inlinable
  public func forEach<ID: Hashable, Element: ReducerProtocol>(
    state toElementsState: WritableKeyPath<State, IdentifiedArray<ID, Element.State>>,
    action toElementAction: CasePath<Action, (ID, Element.Action)>,
    @ReducerBuilder<Element.State, Element.Action> _ element: () -> Element,
    file: StaticString = #file,
    line: UInt = #line
  ) -> ForEachReducer<Self, ID, Element> {
    .init(
      upstream: self,
      toElementsState: toElementsState,
      toElementAction: toElementAction,
      element: element(),
      file: file,
      line: line
    )
  }
}

public struct ForEachReducer<
  Upstream: ReducerProtocol, ID: Hashable, Element: ReducerProtocol
>: ReducerProtocol {
  @usableFromInline
  let upstream: Upstream

  @usableFromInline
  let toElementsState: WritableKeyPath<Upstream.State, IdentifiedArray<ID, Element.State>>

  @usableFromInline
  let toElementAction: CasePath<Upstream.Action, (ID, Element.Action)>

  @usableFromInline
  let element: Element

  @usableFromInline
  let file: StaticString

  @usableFromInline
  let line: UInt

  @inlinable
  init(
    upstream: Upstream,
    toElementsState: WritableKeyPath<Upstream.State, IdentifiedArray<ID, Element.State>>,
    toElementAction: CasePath<Upstream.Action, (ID, Element.Action)>,
    element: Element,
    file: StaticString,
    line: UInt
  ) {
    self.upstream = upstream
    self.toElementsState = toElementsState
    self.toElementAction = toElementAction
    self.element = element
    self.file = file
    self.line = line
  }

  @inlinable
  public func reduce(
    into state: inout Upstream.State, action: Upstream.Action
  ) -> Effect<Upstream.Action, Never> {
    return .merge(
      self.reduceForEach(into: &state, action: action),
      self.upstream.reduce(into: &state, action: action)
    )
  }

  @inlinable
  func reduceForEach(
    into state: inout Upstream.State, action: Upstream.Action
  ) -> Effect<Upstream.Action, Never> {
    guard let (id, elementAction) = self.toElementAction.extract(from: action) else { return .none }
    if state[keyPath: self.toElementsState][id: id] == nil {
      // TODO: Update language
      runtimeWarning(
        """
        A "forEach" reducer at "%@:%d" received an action when state contained no element with \
        that id. …

          Action:
            %@
          ID:
            %@

        This is generally considered an application logic error, and can happen for a few \
        reasons:

        • This "forEach" reducer was combined with or run from another reducer that removed \
        the element at this id when it handled this action. To fix this make sure that this \
        "forEach" reducer is run before any other reducers that can move or remove elements \
        from state. This ensures that "forEach" reducers can handle their actions for the \
        element at the intended id.

        • An in-flight effect emitted this action while state contained no element at this id. \
        It may be perfectly reasonable to ignore this action, but you also may want to cancel \
        the effect it originated from when removing an element from the identified array, \
        especially if it is a long-living effect.

        • This action was sent to the store while its state contained no element at this id. \
        To fix this make sure that actions for this reducer can only be sent to a view store \
        when its state contains an element at this id. In SwiftUI applications, use \
        "ForEachStore".
        """,
        [
          "\(file)",
          line,
          debugCaseOutput(elementAction),
          "\(id)",
        ]
      )
      return .none
    }
    return self.element
      .reduce(into: &state[keyPath: self.toElementsState][id: id]!, action: elementAction)
      .map { self.toElementAction.embed((id, $0)) }
  }
}
