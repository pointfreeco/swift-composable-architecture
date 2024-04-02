extension Reducer {
  /// Embeds a child reducer in a parent domain that works on an optional property of parent state.
  ///
  /// For example, if a parent feature holds onto a piece of optional child state, then it can
  /// perform its core logic _and_ the child's logic by using the `ifLet` operator:
  ///
  /// ```swift
  /// @Reducer
  /// struct Parent {
  ///   struct State {
  ///     var child: Child.State?
  ///     // ...
  ///   }
  ///   enum Action {
  ///     case child(Child.Action)
  ///     // ...
  ///   }
  ///
  ///   var body: some Reducer<State, Action> {
  ///     Reduce { state, action in
  ///       // Core logic for parent feature
  ///     }
  ///     .ifLet(\.child, action: \.child) {
  ///       Child()
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// The `ifLet` operator does a number of things to try to enforce correctness:
  ///
  ///   * It forces a specific order of operations for the child and parent features. It runs the
  ///     child first, and then the parent. If the order was reversed, then it would be possible for
  ///     the parent feature to `nil` out the child state, in which case the child feature would not
  ///     be able to react to that action. That can cause subtle bugs.
  ///
  ///   * It automatically cancels all child effects when it detects the child's state is `nil`'d
  ///     out.
  ///
  ///   * Automatically `nil`s out child state when an action is sent for alerts and confirmation
  ///     dialogs.
  ///
  /// See ``Reducer/ifLet(_:action:destination:fileID:line:)-4f2at`` for a more advanced operator suited
  /// to navigation.
  ///
  /// - Parameters:
  ///   - toWrappedState: A writable key path from parent state to a property containing optional
  ///     child state.
  ///   - toWrappedAction: A case path from parent action to a case containing child actions.
  ///   - wrapped: A reducer that will be invoked with child actions against non-optional child
  ///     state.
  /// - Returns: A reducer that combines the child reducer with the parent reducer.
  @inlinable
  @warn_unqualified_access
  public func ifLet<WrappedState, WrappedAction, Wrapped: Reducer>(
    _ toWrappedState: WritableKeyPath<State, WrappedState?>,
    action toWrappedAction: CaseKeyPath<Action, WrappedAction>,
    @ReducerBuilder<WrappedState, WrappedAction> then wrapped: () -> Wrapped,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> _IfLetReducer<Self, Wrapped>
  where WrappedState == Wrapped.State, WrappedAction == Wrapped.Action {
    .init(
      parent: self,
      child: wrapped(),
      toChildState: toWrappedState,
      toChildAction: AnyCasePath(toWrappedAction),
      fileID: fileID,
      line: line
    )
  }

  /// A special overload of ``Reducer/ifLet(_:action:then:fileID:line:)-42kki`` for alerts
  /// and confirmation dialogs that does not require a child reducer.
  @inlinable
  @warn_unqualified_access
  public func ifLet<WrappedState: _EphemeralState, WrappedAction>(
    _ toWrappedState: WritableKeyPath<State, WrappedState?>,
    action toWrappedAction: CaseKeyPath<Action, WrappedAction>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> _IfLetReducer<Self, EmptyReducer<WrappedState, WrappedAction>> {
    .init(
      parent: self,
      child: EmptyReducer(),
      toChildState: toWrappedState,
      toChildAction: AnyCasePath(toWrappedAction),
      fileID: fileID,
      line: line
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
  public func ifLet<WrappedState, WrappedAction, Wrapped: Reducer>(
    _ toWrappedState: WritableKeyPath<State, WrappedState?>,
    action toWrappedAction: AnyCasePath<Action, WrappedAction>,
    @ReducerBuilder<WrappedState, WrappedAction> then wrapped: () -> Wrapped,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> _IfLetReducer<Self, Wrapped>
  where WrappedState == Wrapped.State, WrappedAction == Wrapped.Action {
    .init(
      parent: self,
      child: wrapped(),
      toChildState: toWrappedState,
      toChildAction: toWrappedAction,
      fileID: fileID,
      line: line
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
  public func ifLet<WrappedState: _EphemeralState, WrappedAction>(
    _ toWrappedState: WritableKeyPath<State, WrappedState?>,
    action toWrappedAction: AnyCasePath<Action, WrappedAction>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> _IfLetReducer<Self, EmptyReducer<WrappedState, WrappedAction>> {
    .init(
      parent: self,
      child: EmptyReducer(),
      toChildState: toWrappedState,
      toChildAction: toWrappedAction,
      fileID: fileID,
      line: line
    )
  }
}

public struct _IfLetReducer<Parent: Reducer, Child: Reducer>: Reducer {
  @usableFromInline
  let parent: Parent

  @usableFromInline
  let child: Child

  @usableFromInline
  let toChildState: WritableKeyPath<Parent.State, Child.State?>

  @usableFromInline
  let toChildAction: AnyCasePath<Parent.Action, Child.Action>

  @usableFromInline
  let fileID: StaticString

  @usableFromInline
  let line: UInt

  @Dependency(\.navigationIDPath) var navigationIDPath

  @usableFromInline
  init(
    parent: Parent,
    child: Child,
    toChildState: WritableKeyPath<Parent.State, Child.State?>,
    toChildAction: AnyCasePath<Parent.Action, Child.Action>,
    fileID: StaticString,
    line: UInt
  ) {
    self.parent = parent
    self.child = child
    self.toChildState = toChildState
    self.toChildAction = toChildAction
    self.fileID = fileID
    self.line = line
  }

  public func reduce(
    into state: inout Parent.State, action: Parent.Action
  ) -> Effect<Parent.Action> {
    let childEffects = self.reduceChild(into: &state, action: action)

    let childIDBefore = state[keyPath: self.toChildState].map {
      NavigationID(base: $0, keyPath: self.toChildState)
    }
    let parentEffects = self.parent.reduce(into: &state, action: action)
    let childIDAfter = state[keyPath: self.toChildState].map {
      NavigationID(base: $0, keyPath: self.toChildState)
    }

    if childIDAfter == childIDBefore,
      self.toChildAction.extract(from: action) != nil,
      let childState = state[keyPath: self.toChildState],
      isEphemeral(childState)
    {
      state[keyPath: toChildState] = nil
    }

    let childCancelEffects: Effect<Parent.Action>
    if let childID = childIDBefore, childID != childIDAfter {
      childCancelEffects = ._cancel(id: childID, navigationID: self.navigationIDPath)
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
    guard state[keyPath: self.toChildState] != nil else {
      var actionDump = ""
      customDump(action, to: &actionDump, indent: 4)
      runtimeWarn(
        """
        An "ifLet" at "\(self.fileID):\(self.line)" received a child action when child state was \
        "nil". …

          Action:
        \(actionDump)

        This is generally considered an application logic error, and can happen for a few reasons:

        • A parent reducer set child state to "nil" before this reducer ran. This reducer must run \
        before any other reducer sets child state to "nil". This ensures that child reducers can \
        handle their actions while their state is still available.

        • An in-flight effect emitted this action when child state was "nil". While it may be \
        perfectly reasonable to ignore this action, consider canceling the associated effect \
        before child state becomes "nil", especially if it is a long-living effect.

        • This action was sent to the store while state was "nil". Make sure that actions for this \
        reducer can only be sent from a view store when state is non-"nil". In SwiftUI \
        applications, use "IfLetStore".
        """
      )
      return .none
    }
    let navigationID = NavigationID(
      base: state[keyPath: self.toChildState]!, keyPath: self.toChildState)
    return self.child
      .dependency(\.navigationIDPath, self.navigationIDPath.appending(navigationID))
      .reduce(into: &state[keyPath: self.toChildState]!, action: childAction)
      .map { self.toChildAction.embed($0) }
      ._cancellable(id: navigationID, navigationIDPath: self.navigationIDPath)
  }
}
