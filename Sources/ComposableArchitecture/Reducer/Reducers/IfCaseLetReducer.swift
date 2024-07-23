extension Reducer {
  /// Embeds a child reducer in a parent domain that works on a case of parent enum state.
  ///
  /// For example, if a parent feature's state is expressed as an enum of multiple children
  /// states, then `ifCaseLet` can run a child reducer on a particular case of the enum:
  ///
  /// ```swift
  /// @Reducer
  /// struct Parent {
  ///   enum State {
  ///     case loggedIn(Authenticated.State)
  ///     case loggedOut(Unauthenticated.State)
  ///   }
  ///   enum Action {
  ///     case loggedIn(Authenticated.Action)
  ///     case loggedOut(Unauthenticated.Action)
  ///     // ...
  ///   }
  ///
  ///   var body: some Reducer<State, Action> {
  ///     Reduce { state, action in
  ///       // Core logic for parent feature
  ///     }
  ///     .ifCaseLet(\.loggedIn, action: \.loggedIn) {
  ///       Authenticated()
  ///     }
  ///     .ifCaseLet(\.loggedOut, action: \.loggedOut) {
  ///       Unauthenticated()
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// The `ifCaseLet` operator does a number of things to try to enforce correctness:
  ///
  ///   * It forces a specific order of operations for the child and parent features. It runs the
  ///     child first, and then the parent. If the order was reversed, then it would be possible for
  ///     the parent feature to change the case of the child enum, in which case the child
  ///     feature would not be able to react to that action. That can cause subtle bugs.
  ///
  ///   * It automatically cancels all child effects when it detects the child enum case changes.
  ///
  /// It is still possible for a parent feature higher up in the application to change the case of
  /// the enum before the child has a chance to react to the action. In such cases a runtime
  /// warning is shown in Xcode to let you know that there's a potential problem.
  ///
  /// - Parameters:
  ///   - toCaseState: A case path from parent state to a case containing child state.
  ///   - toCaseAction: A case path from parent action to a case containing child actions.
  ///   - case: A reducer that will be invoked with child actions against child state when it is
  ///     present
  /// - Returns: A reducer that combines the child reducer with the parent reducer.
  @inlinable
  @warn_unqualified_access
  public func ifCaseLet<CaseState, CaseAction, Case: Reducer>(
    _ toCaseState: CaseKeyPath<State, CaseState>,
    action toCaseAction: CaseKeyPath<Action, CaseAction>,
    @ReducerBuilder<CaseState, CaseAction> then case: () -> Case,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) -> _IfCaseLetReducer<Self, Case>
  where
    State: CasePathable,
    CaseState == Case.State,
    Action: CasePathable,
    CaseAction == Case.Action
  {
    .init(
      parent: self,
      child: `case`(),
      toChildState: AnyCasePath(toCaseState),
      toChildAction: AnyCasePath(toCaseAction),
      fileID: fileID,
      filePath: filePath,
      line: line,
      column: column
    )
  }

  @available(
    iOS,
    deprecated: 9999,
    message:
      "Use the version of this operator with case key paths, instead. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
  )
  @available(
    macOS,
    deprecated: 9999,
    message:
      "Use the version of this operator with case key paths, instead. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
  )
  @available(
    tvOS,
    deprecated: 9999,
    message:
      "Use the version of this operator with case key paths, instead. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
  )
  @available(
    watchOS,
    deprecated: 9999,
    message:
      "Use the version of this operator with case key paths, instead. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
  )
  @inlinable
  @warn_unqualified_access
  public func ifCaseLet<CaseState, CaseAction, Case: Reducer<CaseState, CaseAction>>(
    _ toCaseState: AnyCasePath<State, CaseState>,
    action toCaseAction: AnyCasePath<Action, CaseAction>,
    @ReducerBuilder<CaseState, CaseAction> then case: () -> Case,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) -> some Reducer<State, Action> {
    _IfCaseLetReducer(
      parent: self,
      child: `case`(),
      toChildState: toCaseState,
      toChildAction: toCaseAction,
      fileID: fileID,
      filePath: filePath,
      line: line,
      column: column
    )
  }
}

public struct _IfCaseLetReducer<Parent: Reducer, Child: Reducer>: Reducer {
  @usableFromInline
  let parent: Parent

  @usableFromInline
  let child: Child

  @usableFromInline
  let toChildState: AnyCasePath<Parent.State, Child.State>

  @usableFromInline
  let toChildAction: AnyCasePath<Parent.Action, Child.Action>

  @usableFromInline
  let fileID: StaticString

  @usableFromInline
  let filePath: StaticString

  @usableFromInline
  let line: UInt

  @usableFromInline
  let column: UInt

  @Dependency(\.navigationIDPath) var navigationIDPath

  @usableFromInline
  init(
    parent: Parent,
    child: Child,
    toChildState: AnyCasePath<Parent.State, Child.State>,
    toChildAction: AnyCasePath<Parent.Action, Child.Action>,
    fileID: StaticString,
    filePath: StaticString,
    line: UInt,
    column: UInt
  ) {
    self.parent = parent
    self.child = child
    self.toChildState = toChildState
    self.toChildAction = toChildAction
    self.fileID = fileID
    self.filePath = filePath
    self.line = line
    self.column = column
  }

  public func reduce(
    into state: inout Parent.State, action: Parent.Action
  ) -> Effect<Parent.Action> {
    let childEffects = self.reduceChild(into: &state, action: action)

    let childIDBefore = self.toChildState.extract(from: state).map {
      NavigationID(root: state, value: $0, casePath: self.toChildState)
    }
    let parentEffects = self.parent.reduce(into: &state, action: action)
    let childIDAfter = self.toChildState.extract(from: state).map {
      NavigationID(root: state, value: $0, casePath: self.toChildState)
    }

    let childCancelEffects: Effect<Parent.Action>
    if let childElement = childIDBefore, childElement != childIDAfter {
      childCancelEffects = .cancel(id: childElement)
    } else {
      childCancelEffects = .none
    }

    return .merge(
      childEffects,
      parentEffects,
      childCancelEffects
    )
  }

  func reduceChild(
    into state: inout Parent.State, action: Parent.Action
  ) -> Effect<Parent.Action> {
    guard let childAction = self.toChildAction.extract(from: action)
    else { return .none }
    guard var childState = self.toChildState.extract(from: state) else {
      reportIssue(
        """
        An "ifCaseLet" at "\(self.fileID):\(self.line)" received a child action when child state \
        was set to a different case. …

          Action:
        \(String(customDumping: action).indent(by: 4))
          State:
        \(String(customDumping: state).indent(by: 4))

        This is generally considered an application logic error, and can happen for a few reasons:

        • A parent reducer set "\(typeName(Parent.State.self))" to a different case before this \
        reducer ran. This reducer must run before any other reducer sets child state to a \
        different case. This ensures that child reducers can handle their actions while their \
        state is still available.

        • An in-flight effect emitted this action when child state was unavailable. While it may \
        be perfectly reasonable to ignore this action, consider canceling the associated effect \
        before child state changes to another case, especially if it is a long-living effect.

        • This action was sent to the store while state was another case. Make sure that actions \
        for this reducer can only be sent from a view store when state is set to the appropriate \
        case. In SwiftUI applications, use "SwitchStore".
        """,
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
      )
      return .none
    }
    defer { state = self.toChildState.embed(childState) }
    let childID = NavigationID(root: state, value: childState, casePath: self.toChildState)
    let newNavigationID = self.navigationIDPath.appending(childID)
    return self.child
      .dependency(\.navigationIDPath, newNavigationID)
      .reduce(into: &childState, action: childAction)
      .map { self.toChildAction.embed($0) }
      .cancellable(id: childID)
  }
}
