public protocol CaseReducer<State, Action> {
  associatedtype State: CaseReducerState where State.Reducer == Self
  associatedtype Action
  associatedtype Body: Reducer<State, Action>
  associatedtype Cases

  @ReducerBuilder<State, Action>
  static var body: Body { get }

  static func cases(_ store: Store<State, Action>) -> Cases
}

public protocol CaseReducerState {
  associatedtype Reducer: CaseReducer where Reducer.State == Self
}

extension Reducer {
  public func ifLet<ChildState: CaseReducerState, ChildAction>(
    _ state: WritableKeyPath<State, PresentationState<ChildState>>,
    action: CaseKeyPath<Action, PresentationAction<ChildAction>>
  ) -> some ReducerOf<Self> where ChildState.Reducer.Action == ChildAction {
    self.ifLet(state, action: action) {
      ChildState.Reducer.body
    }
  }

  public func forEach<DestinationState: CaseReducerState, DestinationAction>(
    _ state: WritableKeyPath<State, StackState<DestinationState>>,
    action: CaseKeyPath<Action, StackAction<DestinationState, DestinationAction>>
  ) -> some ReducerOf<Self> where DestinationState.Reducer.Action == DestinationAction {
    self.forEach(state, action: action) {
      DestinationState.Reducer.body
    }
  }
}

extension Store where State: CaseReducerState, State.Reducer.Action == Action {
  public var cases: State.Reducer.Cases {
    State.Reducer.cases(self)
  }
}

