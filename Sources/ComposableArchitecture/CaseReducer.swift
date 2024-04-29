/// A reducer represented by multiple enum cases.
///
/// You should not conform to this protocol directly. Instead, the ``Reducer()`` macro will add a
/// conformance to enums.
public protocol CaseReducer<State, Action>: Reducer
where State: CaseReducerState, Body: Reducer, Body.State == State, Body.Action == Action {
  associatedtype State = State
  associatedtype Action = Action
  associatedtype Body = Body
  associatedtype CaseScope

  @ReducerBuilder<State, Action>
  static var body: Body { get }

  static func scope(_ store: Store<State, Action>) -> CaseScope
}

extension CaseReducer {
  public var body: Body {
    Self.body
  }
}

/// A state type that is associated with a ``CaseReducer``.
public protocol CaseReducerState {
  associatedtype StateReducer: CaseReducer where StateReducer.State == Self
}

extension Reducer {
  /// A special overload of ``Reducer/ifLet(_:action:destination:fileID:line:)-4f2at`` for enum
  /// reducers.
  public func ifLet<ChildState: CaseReducerState, ChildAction>(
    _ state: WritableKeyPath<State, PresentationState<ChildState>>,
    action: CaseKeyPath<Action, PresentationAction<ChildAction>>
  ) -> some ReducerOf<Self> where ChildState.StateReducer.Action == ChildAction {
    self.ifLet(state, action: action) {
      ChildState.StateReducer.body
    }
  }

  /// A special overload of ``Reducer/forEach(_:action:destination:fileID:line:)-yz3v`` for enum
  /// reducers.
  public func forEach<DestinationState: CaseReducerState, DestinationAction>(
    _ state: WritableKeyPath<State, StackState<DestinationState>>,
    action: CaseKeyPath<Action, StackAction<DestinationState, DestinationAction>>
  ) -> some ReducerOf<Self> where DestinationState.StateReducer.Action == DestinationAction {
    self.forEach(state, action: action) {
      DestinationState.StateReducer.body
    }
  }
}

extension Store where State: CaseReducerState, State.StateReducer.Action == Action {
  /// A destructurable view of a store on a collection of cases.
  public var `case`: State.StateReducer.CaseScope {
    State.StateReducer.scope(self)
  }
}
