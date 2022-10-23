extension ReducerProtocol {
  #if swift(>=5.7)
    /// Embeds a child reducer in a parent domain that works on elements of a collection in parent
    /// state.
    ///
    /// For example, if a parent feature holds onto an array of child states, then it can perform
    /// its core logic _and_ the child's logic by using the `forEach` operator:
    ///
    /// ```swift
    /// struct Parent: ReducerProtocol {
    ///   struct State {
    ///     var rows: IdentifiedArrayOf<Row.State>
    ///     // ...
    ///   }
    ///   enum Action {
    ///     case row(id: Row.State.ID, action: Row.Action)
    ///     // ...
    ///   }
    ///
    ///   var body: some ReducerProtocol<State, Action> {
    ///     Reduce { state, action in
    ///       // Core logic for parent feature
    ///     }
    ///     .forEach(\.rows, action: /Action.row) {
    ///       Row()
    ///     }
    ///   }
    /// }
    /// ```
    ///
    /// The `forEach` forces a specific order of operations for the child and parent features. It
    /// runs the child first, and then the parent. If the order was reversed, then it would be
    /// possible for the parent feature to remove the child state from the array, in which case the
    /// child feature would not be able to react to that action. That can cause subtle bugs.
    ///
    /// It is still possible for a parent feature higher up in the application to remove the child
    /// state from the array before the child has a chance to react to the action. In such cases a
    /// runtime warning is shown in Xcode to let you know that there's a potential problem.
    ///
    /// - Parameters:
    ///   - toElementsState: A writable key path from parent state to a `StateContainer` of child
    ///   state.
    ///   - toElementAction: A case path from parent action to child identifier and child actions.
    ///   - element: A reducer that will be invoked with child actions against elements of child
    ///     state.
    /// - Returns: A reducer that combines the child reducer with the parent reducer.
    @inlinable
    public func forEach<States: MutableStateContainer, ElementState, ElementAction>(
      _ toElementsState: WritableKeyPath<State, States>,
      action toElementAction: CasePath<Action, (States.Tag, ElementAction)>,
      @ReducerBuilder<ElementState, ElementAction> _ element: () -> some ReducerProtocol<
        ElementState, ElementAction
      >,
      file: StaticString = #file,
      fileID: StaticString = #fileID,
      line: UInt = #line
    ) -> some ReducerProtocol<State, Action> where States.State == ElementState {
      _ContainedStateReducer(
        parent: self,
        toStateContainer: toElementsState,
        toContentAction: toElementAction,
        content: element(),
        file: file,
        fileID: fileID,
        line: line,
        onStateExtractionFailure: self.onForEachStateExtractionFailure()
      )
    }
  #else
    @inlinable
    public func forEach<States: IdentifiedStates, Element: ReducerProtocol>(
      _ toElementsState: WritableKeyPath<State, States>,
      action toElementAction: CasePath<Action, (States.Tag, Element.Action)>,
      @ReducerBuilderOf<Element> _ element: () -> Element,
      file: StaticString = #file,
      fileID: StaticString = #fileID,
      line: UInt = #line
    ) -> _ContainedStateReducer<Self, States, Element> {
      _ContainedStateReducer(
        parent: self,
        toStateContainer: toElementsState,
        toContentAction: toElementAction,
        content: element(),
        file: file,
        fileID: fileID,
        line: line,
        onStateExtractionFailure: self.onForEachStateExtractionFailure()
      )
    }
  #endif
}

extension ReducerProtocol {
  @usableFromInline
  func onForEachStateExtractionFailure() -> StateExtractionFailureHandler<State, Action> {
    .init { state, action, file, fileID, line in
      runtimeWarn(
        """
        A "forEach" at "\(fileID):\(line)" received an action for a missing element.

          Action:
            \(debugCaseOutput(action))

        This is generally considered an application logic error, and can happen for a few reasons:

        • A parent reducer removed an element with this ID before this reducer ran. This reducer \
        must run before any other reducer removes an element, which ensures that element reducers \
        can handle their actions while their state is still available.

        • An in-flight effect emitted this action when state contained no element at this ID. \
        While it may be perfectly reasonable to ignore this action, consider canceling the \
        associated effect before an element is removed, especially if it is a long-living effect.

        • This action was sent to the store while its state contained no element at this ID. To \
        fix this make sure that actions for this reducer can only be sent from a view store when \
        its state contains an element at this id. In SwiftUI applications, use "ForEachStore".
        """,
        file: file,
        line: line
      )
    }
  }
}

extension IdentifiedArray: MutableStateContainer {
  public func extract(tag: ID) -> Element? {
    self[id: tag]
  }

  public mutating func embed(tag: ID, state: Element) {
    self[id: tag] = state
  }

  public mutating func modify<Value>(tag: ID, _ body: (inout Element) -> Value) -> Value {
    body(&self[id: tag]!)
  }
}

import OrderedCollections
extension OrderedDictionary: MutableStateContainer {
  public func extract(tag: Key) -> Value? {
    self[tag]
  }

  public mutating func embed(tag: Key, state: Value) {
    self[tag] = state
  }

  public mutating func modify<T>(tag: Key, _ body: (inout Value) -> T) -> T {
    body(&self[tag]!)
  }
}
