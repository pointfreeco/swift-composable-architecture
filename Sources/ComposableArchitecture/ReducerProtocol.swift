public protocol ReducerProtocol<State, Action> {
  associatedtype State

  associatedtype Action

  associatedtype Body: ReducerProtocol<State, Action> = Self

  func reduce(into state: inout State, action: Action) -> Effect<Action, Never>

  @ReducerBuilder<State, Action>
  var body: Body { get }
}

extension ReducerProtocol where Body == Self {
  public var body: Body { self }
}

extension ReducerProtocol {
  public func reduce(
    into state: inout Body.State, action: Body.Action
  ) -> Effect<Body.Action, Never> {
    self.body.reduce(into: &state, action: action)
  }
}

public struct Combined<R0: ReducerProtocol, R1: ReducerProtocol>: ReducerProtocol
where R0.State == R1.State, R0.Action == R1.Action {
  let r0: R0
  let r1: R1

  public func reduce(into state: inout R0.State, action: R0.Action) -> Effect<R0.Action, Never> {
    .merge(
      self.r0.reduce(into: &state, action: action),
      self.r1.reduce(into: &state, action: action)
    )
  }
}

public struct Scope<Local: ReducerProtocol, GlobalState, GlobalAction>: ReducerProtocol {
  let toLocalState: WritableKeyPath<GlobalState, Local.State>
  let toLocalAction: CasePath<GlobalAction, Local.Action>
  let localReducer: Local

  public init(
    state toLocalState: WritableKeyPath<GlobalState, Local.State>,
    action toLocalAction: CasePath<GlobalAction, Local.Action>,
    @ReducerBuilder<Local.State, Local.Action> _ build: () -> Local
  ) {
    self.toLocalState = toLocalState
    self.toLocalAction = toLocalAction
    self.localReducer = build()
  }

  public func reduce(
    into state: inout GlobalState, action: GlobalAction
  ) -> Effect<GlobalAction, Never> {
    guard let localAction = self.toLocalAction.extract(from: action)
    else { return .none }
    return self.localReducer
      .reduce(into: &state[keyPath: self.toLocalState], action: localAction)
      .map(self.toLocalAction.embed)
  }
}

public typealias Pullback = Scope

extension ReducerProtocol {
  public func pullback<GlobalState, GlobalAction>(
    state toLocalState: WritableKeyPath<GlobalState, State>,
    action toLocalAction: CasePath<GlobalAction, Action>
  ) -> Pullback<Self, GlobalState, GlobalAction> {
    Pullback(state: toLocalState, action: toLocalAction) {
      self
    }
  }
}

@resultBuilder
public enum ReducerBuilder<State, Action> {
  public static func buildExpression<R: ReducerProtocol<State, Action>>(_ expression: R) -> R {
    expression
  }

  public static func buildPartialBlock<R: ReducerProtocol<State, Action>>(first: R) -> R {
    first
  }

  public static func buildPartialBlock<
    R0: ReducerProtocol<State, Action>, R1: ReducerProtocol<State, Action>
  >(accumulated: R0, next: R1) -> Combined<R0, R1> {
    .init(r0: accumulated, r1: next)
  }
}

extension Reducer where Environment == Void {
  public init<R: ReducerProtocol<State, Action>>(_ reducer: R) {
    self.init { state, action, _ in reducer.reduce(into: &state, action: action) }
  }
}

extension Store {
  public convenience init<R: ReducerProtocol<State, Action>>(
    initialState: State,
    reducer: R
  ) {
    self.init(
      initialState: initialState,
      reducer: .init(reducer),
      environment: ()
    )
  }
}
