//public struct Reducer<State, Action, Environment> {
//  private let reducer: (inout State, Action, Environment) -> Effect<Action, Never>

/*
 Reduce { state, action, environment in
 }
 */

public protocol ReducerProtocol {
  associatedtype State
  associatedtype Action

  func reduce(
    into state: inout State,
    action: Action
  ) -> Effect<Action, Never>
}

public struct EmptyReducer<State, Action>: ReducerProtocol {
  public init() {}
  public func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
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
  var date: () -> Date = { Date() }
  var mainQueue: AnySchedulerOf<DispatchQueue> = .main

  func reduce(
    into state: inout State,
    action: Action
  ) -> Effect<Action, Never> {
    switch action {
    case .incrementButtonTapped:
      state.count += 1
      return .run { send in
        let x = 1
        await send(.decrementButtonTapped)
      }
    case .decrementButtonTapped:
      state.count -= 1
      return .none
    }
  }
}

//func counterReducer(
//  date: () -> Date = { Date() },
//  mainQueue: AnySchedulerOf<DispatchQueue> = .main
//) -> Reducer<CounterState, CounterAction> {
//  .init { state, action in
//    …
//  }
//}


extension ReducerProtocol {
  public func combine<R: ReducerProtocol>(with reducer: R) -> CombineReducer<Self, R>
  where R.State == State, R.Action == Action
  {
    .init(lhs: self, rhs: reducer)
  }
}
public struct CombineReducer<LHS: ReducerProtocol, RHS: ReducerProtocol>: ReducerProtocol
where LHS.State == RHS.State, LHS.Action == RHS.Action
{
  let lhs: LHS
  let rhs: RHS

  public func reduce(into state: inout LHS.State, action: LHS.Action) -> Effect<LHS.Action, Never> {
    .merge(
      self.lhs.reduce(into: &state, action: action),
      self.rhs.reduce(into: &state, action: action)
    )
  }
}

let reducer = Counter()
  .combine(with: Counter())
  .combine(with: Counter())
  .combine(with: Counter())
// let reducer: CombineReducer<CombineReducer<CombineReducer<Counter, Counter>, Counter>, Counter>
