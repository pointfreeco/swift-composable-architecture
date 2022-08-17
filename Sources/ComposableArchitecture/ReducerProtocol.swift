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

extension ReducerProtocol {
  public func pullback<ParentState, ParentAction>(
    state toChildState: WritableKeyPath<ParentState, State>,
    action toChildAction: CasePath<ParentAction, Action>
  ) -> PullbackReducer<ParentState, ParentAction, Self> {
    PullbackReducer(
      toChildState: toChildState,
      toChildAction: toChildAction,
      child: self
    )
  }
}

public struct PullbackReducer<ParentState, ParentAction, Child: ReducerProtocol>: ReducerProtocol {
  let toChildState: WritableKeyPath<ParentState, Child.State>
  let toChildAction: CasePath<ParentAction, Child.Action>
  let child: Child

  public func reduce(
    into state: inout ParentState, action: ParentAction
  ) -> Effect<ParentAction, Never> {
    guard let childAction = self.toChildAction.extract(from: action)
    else { return .none }
    return self.child
      .reduce(into: &state[keyPath: self.toChildState], action: childAction)
      .map(self.toChildAction.embed)
  }
}


public typealias StoreOf<R: ReducerProtocol> = Store<R.State, R.Action>

extension Reducer {
  public init<R: ReducerProtocol>(_ reducer: R)
  where R.State == State, R.Action == Action {
    self.init { state, action, _ in
      reducer.reduce(into: &state, action: action)
    }
  }
}


extension ReducerProtocol {
  public func optional() -> OptionalReducer<Self> {
    OptionalReducer(wrapped: self)
  }
}

public struct OptionalReducer<Wrapped: ReducerProtocol>: ReducerProtocol {
  let wrapped: Wrapped
  public func reduce(
    into state: inout Wrapped.State?, action: Wrapped.Action
  ) -> Effect<Wrapped.Action, Never> {
    guard state != nil else {
      runtimeWarning(
        """
        An "optional" reducer received an action when state was "nil".
        """
      )
      return .none
    }
    return self.wrapped.reduce(into: &state!, action: action)
  }
}


extension ReducerProtocol {
  public func forEach<ParentState, ParentAction, ID>(
    state toElementsState: WritableKeyPath<ParentState, IdentifiedArray<ID, State>>,
    action toElementAction: CasePath<ParentAction, (ID, Action)>
  ) -> ForEachReducer<ParentState, ParentAction, ID, Self> {
    ForEachReducer(
      toElementsState: toElementsState,
      toElementAction: toElementAction,
      element: self
    )
  }
}

public struct ForEachReducer<State, Action, ID: Hashable, Element: ReducerProtocol>: ReducerProtocol
{
  let toElementsState: WritableKeyPath<State, IdentifiedArray<ID, Element.State>>
  let toElementAction: CasePath<Action, (ID, Element.Action)>
  let element: Element

  public func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    guard let (id, elementAction) = toElementAction.extract(from: action) else { return .none }
    if state[keyPath: toElementsState][id: id] == nil {
      runtimeWarning(
        """
        A "forEach" reducer received an action when state contained no element with that id.
        """
      )
      return .none
    }
    return self.element
      .reduce(
        into: &state[keyPath: toElementsState][id: id]!,
        action: elementAction
      )
      .map { toElementAction.embed((id, $0)) }
  }
}


public struct Reduce<State, Action>: ReducerProtocol {
  let reduce: (inout State, Action) -> Effect<Action, Never>

  public init(_ reduce: @escaping (inout State, Action) -> Effect<Action, Never>) {
    self.reduce = reduce
  }

  public func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    self.reduce(&state, action)
  }
}
