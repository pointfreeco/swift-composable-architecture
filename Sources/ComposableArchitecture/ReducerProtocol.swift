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

//let reducer = Counter()
//  .combine(with: Counter())
//  .combine(with: Counter())
//  .combine(with: Counter())
// let reducer: CombineReducer<CombineReducer<CombineReducer<Counter, Counter>, Counter>, Counter>

extension ReducerProtocol {
  public func pullback<ParentState, ParentAction>(
    state toChildState: WritableKeyPath<ParentState, State>,
    action toChildAction: CasePath<ParentAction, Action>
  ) -> Scope<ParentState, ParentAction, Self> {
    Scope(
      state: toChildState,
      action: toChildAction
    ) {
      self
    }
  }
}

public struct Scope<ParentState, ParentAction, Child: ReducerProtocol>: ReducerProtocol {
  let toChildState: WritableKeyPath<ParentState, Child.State>
  let toChildAction: CasePath<ParentAction, Child.Action>
  let child: Child

  public init(
    state toChildState: WritableKeyPath<ParentState, Child.State>,
    action toChildAction: CasePath<ParentAction, Child.Action>,
    @ReducerBuilder child: () -> Child
  ) {
    self.toChildState = toChildState
    self.toChildAction = toChildAction
    self.child = child()
  }

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
  public func forEach<ID: Hashable, Element: ReducerProtocol>(
    state toElementsState: WritableKeyPath<State, IdentifiedArray<ID, Element.State>>,
    action toElementAction: CasePath<Action, (ID, Element.Action)>,
    @ReducerBuilder _ element: () -> Element
  ) -> ForEachReducer<Self, ID, Element> {
    .init(
      parent: self,
      toElementsState: toElementsState,
      toElementAction: toElementAction,
      element: element()
    )
  }
}
public struct ForEachReducer<
  Parent: ReducerProtocol,
  ID: Hashable,
  Element: ReducerProtocol
>: ReducerProtocol
{
  public let parent: Parent
  public let toElementsState: WritableKeyPath<Parent.State, IdentifiedArray<ID, Element.State>>
  public let toElementAction: CasePath<Action, (ID, Element.Action)>
  public let element: Element

  public func reduce(
    into state: inout Parent.State,
    action: Parent.Action
  ) -> Effect<Parent.Action, Never> {
    return .merge(
      self.reduceForEach(into: &state, action: action),
      self.parent.reduce(into: &state, action: action)
    )
  }

  func reduceForEach(
    into state: inout Parent.State, action: Parent.Action
  ) -> Effect<Parent.Action, Never> {
    guard let (id, elementAction) = self.toElementAction.extract(from: action) else { return .none }
    if state[keyPath: self.toElementsState][id: id] == nil {
      // TODO: Update language
      runtimeWarning(
        """
        A "forEach" reducer received an action when state contained no element with that id.
        """
      )
      return .none
    }
    return self.element
      .reduce(into: &state[keyPath: self.toElementsState][id: id]!, action: elementAction)
      .map { self.toElementAction.embed((id, $0)) }
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


@resultBuilder
public enum ReducerBuilder {
  public static func buildPartialBlock<R: ReducerProtocol>(first: R) -> R {
    first
  }
  public static func buildPartialBlock<R0: ReducerProtocol, R1: ReducerProtocol>(
    accumulated r0: R0,
    next r1: R1
  ) -> CombineReducer<R0, R1> {
    .init(lhs: r0, rhs: r1)
  }
}

public struct CombineReducers<R: ReducerProtocol>: ReducerProtocol {
  let reducer: R
  public init(@ReducerBuilder build: () -> R) {
    self.reducer = build()
  }
  public func reduce(into state: inout R.State, action: R.Action) -> Effect<R.Action, Never> {
    self.reducer.reduce(into: &state, action: action)
  }
}

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
  Counter()
  Counter()
  Counter()
  Counter()
  Counter()
  Counter()
  Counter()
  Counter()
}

/*

 a
 b
 c
 buildBlock(a, b, c)

 if condition {
   a
 }
 buildOptional(a)

 if condition {
   a
 } else {
   b
 }
 buildEither(first: a)
 buildEither(second: b)


 a
 buildPartialBlock(first: a)
 b
 buildPartialBlock(accumulated: buildPartialBlock(first: a), next: b)
 c
 buildPartialBlock(accumulated: buildPartialBlock(accumulated: buildPartialBlock(first: a), next: b), next: c)
 d
 buildPartialBlock(
   accumulated: buildPartialBlock(
     accumulated: buildPartialBlock(
       accumulated: buildPartialBlock(first: a),
       next: b
     ),
     next: c
   ),
   next: d
 )

 */

extension ReducerProtocol {
  public func ifLet<Child: ReducerProtocol>(
    state toChildState: WritableKeyPath<State, Child.State?>,
    action toChildAction: CasePath<Action, Child.Action>,
    @ReducerBuilder child: () -> Child
  ) -> IfLetReducer<Self, Child> {
    .init(
      parent: self,
      child: child(),
      toChildState: toChildState,
      toChildAction: toChildAction
    )
  }
}

public struct IfLetReducer<Parent: ReducerProtocol, Child: ReducerProtocol>: ReducerProtocol {
  let parent: Parent
  let child: Child
  let toChildState: WritableKeyPath<Parent.State, Child.State?>
  let toChildAction: CasePath<Parent.Action, Child.Action>

  public func reduce(into state: inout Parent.State, action: Parent.Action) -> Effect<Parent.Action, Never> {
    CombineReducers {
      Scope(state: self.toChildState, action: self.toChildAction) {
        self.child.optional()
      }
      self.parent
    }
    .reduce(into: &state, action: action)
  }
}
