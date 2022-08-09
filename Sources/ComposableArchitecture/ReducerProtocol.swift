
public protocol ReducerProtocol {
  associatedtype State
  associatedtype Action
  associatedtype Environment

  func reduce(
    into state: inout State,
    action: Action,
    environment: Environment
  ) -> Effect<Action, Never>
}

public struct EmptyReducer<State, Action, Environment>: ReducerProtocol {
  public init() {}
  public func reduce(
    into _: inout State, action _: Action, environment _: Environment
  ) -> Effect<Action, Never> {
    .none
  }
}

struct Counter: ReducerProtocol {
  struct State {
    var count = 0
  }
  enum Action {
    case incrementButtonTapped
    case decrementButtonTapped
  }
  struct Environment {}

  func reduce(
    into state: inout State, action: Action, environment: Environment
  ) -> Effect<Action, Never> {
    switch action {
    case .incrementButtonTapped:
      state.count += 1
      return .none
    case .decrementButtonTapped:
      state.count -= 1
      return .none
    }
  }
}


extension ReducerProtocol {
  public func combine<R: ReducerProtocol>(with other: R) -> CombineReducer<Self, R>
  where
    State == R.State,
    Action == R.Action,
    Environment == R.Environment
  {
    .init(lhs: self, rhs: other)
  }
}


public struct CombineReducer<LHS: ReducerProtocol, RHS: ReducerProtocol>: ReducerProtocol
where
  LHS.State == RHS.State,
  LHS.Action == RHS.Action,
  LHS.Environment == RHS.Environment
{
  public let lhs: LHS
  public let rhs: RHS
  public init(lhs: LHS, rhs: RHS) {
    self.lhs = lhs
    self.rhs = rhs
  }
  public func reduce(
    into state: inout LHS.State,
    action: LHS.Action,
    environment: LHS.Environment
  ) -> Effect<LHS.Action, Never> {
    .merge(
      lhs.reduce(into: &state, action: action, environment: environment),
      rhs.reduce(into: &state, action: action, environment: environment)
    )
  }
}

public struct CombineReducers<R: ReducerProtocol>: ReducerProtocol {
  public let reducer: R
  public init(@ReducerBuilder build: () -> R) {
    self.reducer = build()
  }
  public func reduce(
    into state: inout R.State,
    action: R.Action,
    environment: R.Environment
  ) -> Effect<R.Action, Never> {
    self.reducer.reduce(into: &state, action: action, environment: environment)
  }
}

@resultBuilder
public enum ReducerBuilder {
  public static func buildPartialBlock<R: ReducerProtocol>(first: R) -> R {
    first
  }
  public static func buildPartialBlock<R0: ReducerProtocol, R1: ReducerProtocol>(
    accumulated: R0, next: R1
  ) -> CombineReducer<R0, R1> {
    .init(lhs: accumulated, rhs: next)
  }
}

//struct Scope


let reducer = CombineReducers {
  Counter()
  Counter()
  Counter()
  Counter()
  Counter()
  Counter()
  Counter()
  Counter()
  Counter()
}
