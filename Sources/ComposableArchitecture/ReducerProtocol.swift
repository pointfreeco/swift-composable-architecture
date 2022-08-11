public protocol ReducerProtocol<State, Action> {
  associatedtype State
  associatedtype Action
  associatedtype Body

  @ReducerBuilder<State, Action>
  var body: Body { get }

  func reduce(
    into state: inout State,
    action: Action
  ) -> Effect<Action, Never>
}

extension ReducerProtocol where Body == Never {
  public var body: Body {
    fatalError()
  }
}
extension ReducerProtocol
where
  Body: ReducerProtocol,
  Body.State == State,
  Body.Action == Action
{
  public func reduce(
    into state: inout Body.State,
    action: Body.Action
  ) -> Effect<Body.Action, Never> {
    self.body.reduce(into: &state, action: action)
  }
}


public struct EmptyReducer<State, Action>: ReducerProtocol {
  public init() {}
  public func reduce(
    into _: inout State, action _: Action
  ) -> Effect<Action, Never> {
    .none
  }
}

extension ReducerProtocol {
  public func combine<R: ReducerProtocol>(with other: R) -> CombineReducer<Self, R>
  where
    State == R.State,
    Action == R.Action
  {
    .init(lhs: self, rhs: other)
  }
}

public struct CombineReducer<LHS: ReducerProtocol, RHS: ReducerProtocol>: ReducerProtocol
where
  LHS.State == RHS.State,
  LHS.Action == RHS.Action
{
  public let lhs: LHS
  public let rhs: RHS

  public init(lhs: LHS, rhs: RHS) {
    self.lhs = lhs
    self.rhs = rhs
  }
  public func reduce(
    into state: inout LHS.State,
    action: LHS.Action
  ) -> Effect<LHS.Action, Never> {
    .merge(
      lhs.reduce(into: &state, action: action),
      rhs.reduce(into: &state, action: action)
    )
  }
}

extension ReducerProtocol {
  public func pullback<GlobalState, GlobalAction>(
    state toLocalState: WritableKeyPath<GlobalState, State>,
    action toLocalAction: CasePath<GlobalAction, Action>
  ) -> PullbackReducer<GlobalState, GlobalAction, Self> {
    .init(toLocalState: toLocalState, toLocalAction: toLocalAction, localReducer: self)
  }
}

public struct PullbackReducer<State, Action, Local: ReducerProtocol>: ReducerProtocol {
  public let toLocalState: WritableKeyPath<State, Local.State>
  public let toLocalAction: CasePath<Action, Local.Action>
  public let localReducer: Local
  public init(
    toLocalState: WritableKeyPath<State, Local.State>,
    toLocalAction: CasePath<Action, Local.Action>,
    localReducer: Local
  ) {
    self.toLocalState = toLocalState
    self.toLocalAction = toLocalAction
    self.localReducer = localReducer
  }
  public func reduce(
    into state: inout State,
    action: Action
  ) -> Effect<Action, Never> {
    guard let localAction = self.toLocalAction.extract(from: action)
    else { return .none }
    return self.localReducer
      .reduce(into: &state[keyPath: self.toLocalState], action: localAction)
      .map(self.toLocalAction.embed)

  }
}

struct TabA: ReducerProtocol {
  struct State {}
  enum Action {}
  func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    .none
  }
}
struct TabB: ReducerProtocol {
  struct State {}
  enum Action {}
  func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    .none
  }
}
struct TabC: ReducerProtocol {
  struct State {}
  enum Action {}
  func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    .none
  }
}

struct AppReducer: ReducerProtocol {
  struct State {
    var tabA: TabA.State
    var tabB: TabB.State
    var tabC: TabC.State
  }
  enum Action {
    case tabA(TabA.Action)
    case tabB(TabB.Action)
    case tabC(TabC.Action)
  }
  func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    Self.core
      .reduce(into: &state, action: action)
  }
  static let core = TabA()
    .pullback(state: \State.tabA, action: /Action.tabA)
    .combine(
      with: TabB()
        .pullback(state: \State.tabB, action: /Action.tabB)
    )
    .combine(
      with: TabC()
        .pullback(state: \State.tabC, action: /Action.tabC)
    )
}


//let appReducer = Reducer.combine(
//  TabA()
//    .pullback(state: \AppState.tabA, action: /AppAction.tabA),
//  TabB()
//    .pullback(state: \AppState.tabB, action: /AppAction.tabB),
//  TabC()
//    .pullback(state: \AppState.tabC, action: /AppAction.tabC)
//)
// let appReducer: CombineReducer<CombineReducer<PullbackReducer<AppState, AppAction, TabA>, PullbackReducer<AppState, AppAction, TabB>>, PullbackReducer<AppState, AppAction, TabC>>

extension Reducer {
  public init<R: ReducerProtocol>(_ r: R) where R.State == State, R.Action == Action {
    self.init { state, action, _ in
      r.reduce(into: &state, action: action)
    }
  }
}

public typealias StoreOf<R: ReducerProtocol> = Store<R.State, R.Action>

extension ReducerProtocol {
  public func optional() -> OptionalReducer<Self> {
    .init(reducer: self)
  }
}
public struct OptionalReducer<R: ReducerProtocol>: ReducerProtocol {
  public let reducer: R
  public func reduce(into state: inout R.State?, action: R.Action) -> Effect<R.Action, Never> {
    guard state != nil else {
      runtimeWarning(
        """
        An "optional" reducer received an action when state was "nil".
        """
      )
      return .none
    }
    return self.reducer.reduce(into: &state!, action: action)
  }
}

extension ReducerProtocol {
  public func forEach<ID: Hashable, Element: ReducerProtocol>(
    state toElementsState: WritableKeyPath<State, IdentifiedArray<ID, Element.State>>,
    action toElementAction: CasePath<Action, (ID, Element.Action)>,
    @ReducerBuilderOf<Element> _ element: () -> Element
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
  public let toElementsState: WritableKeyPath<State, IdentifiedArray<ID, Element.State>>
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
  public let reduce: (inout State, Action) -> Effect<Action, Never>
  public init(_ reduce: @escaping (inout State, Action) -> Effect<Action, Never>) {
    self.reduce = reduce
  }
  public func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    self.reduce(&state, action)
  }
}

@resultBuilder
public enum ReducerBuilder<State, Action> {
  public static func buildPartialBlock<R: ReducerProtocol<State, Action>>(first: R) -> R {
    first
  }
  public static func buildPartialBlock<
    R0: ReducerProtocol<State, Action>,
    R1: ReducerProtocol<State, Action>
  >(accumulated: R0, next: R1) -> CombineReducer<R0, R1> {
    .init(lhs: accumulated, rhs: next)
  }
  public static func buildExpression<R: ReducerProtocol<State, Action>>(_ expression: R) -> R {
    expression
  }
}

public typealias ReducerBuilderOf<R: ReducerProtocol> = ReducerBuilder<R.State, R.Action>

public struct CombineReducers<R: ReducerProtocol>: ReducerProtocol {
  public let reducer: R
  public init(@ReducerBuilderOf<R> build: () -> R) {
    self.reducer = build()
  }
  public func reduce(
    into state: inout R.State,
    action: R.Action
  ) -> Effect<R.Action, Never> {
    self.reducer.reduce(into: &state, action: action)
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

  func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
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
}

public struct Scope<State, Action, Local: ReducerProtocol>: ReducerProtocol {
  let toLocalState: WritableKeyPath<State, Local.State>
  let toLocalAction: CasePath<Action, Local.Action>
  let localReducer: Local

  public init(
    state toLocalState: WritableKeyPath<State, Local.State>,
    action toLocalAction: CasePath<Action, Local.Action>,
    @ReducerBuilderOf<Local> _ local: () -> Local
  ) {
    self.toLocalState = toLocalState
    self.toLocalAction = toLocalAction
    self.localReducer = local()
  }

  public func reduce(
    into state: inout State,
    action: Action
  ) -> Effect<Action, Never> {
    guard let localAction = self.toLocalAction.extract(from: action)
    else { return .none }
    return self.localReducer
      .reduce(
        into: &state[keyPath: self.toLocalState],
        action: localAction
      )
      .map(self.toLocalAction.embed)
  }
}

extension ReducerProtocol {
  public func ifLet<Child: ReducerProtocol>(
    state toChildState: WritableKeyPath<State, Child.State?>,
    action toChildAction: CasePath<Action, Child.Action>,
    @ReducerBuilderOf<Child> then child: () -> Child
  ) -> IfLetReducer<Self, Child> {
    .init(
      upstream: self,
      child: child(),
      toChildState: toChildState,
      toChildAction: toChildAction
    )
  }
}
public struct IfLetReducer<Parent: ReducerProtocol, Child: ReducerProtocol>: ReducerProtocol {
  let upstream: Parent
  let child: Child
  let toChildState: WritableKeyPath<State, Child.State?>
  let toChildAction: CasePath<Action, Child.Action>

  public func reduce(
    into state: inout Parent.State,
    action: Parent.Action
  ) -> Effect<Parent.Action, Never> {
    .merge(
      self.reduceChild(into: &state, action: action),
      self.upstream.reduce(into: &state, action: action)
    )
  }

  func reduceChild(
    into state: inout Parent.State,
    action: Parent.Action
  ) -> Effect<Parent.Action, Never> {
    guard let wrappedAction = self.toChildAction.extract(from: action)
    else { return .none }
    guard state[keyPath: self.toChildState] != nil else {
      // TODO: Update language
      runtimeWarning(
        """
        An "ifLet" reducer  received an action when state was "nil".
        """
      )
      return .none
    }
    return self.child.reduce(into: &state[keyPath: self.toChildState]!, action: wrappedAction)
      .map(self.toChildAction.embed)
  }
}


public typealias ReducerProtocolOf<R: ReducerProtocol> = ReducerProtocol<R.State, R.Action>

struct App: ReducerProtocol {
  struct State {
    var tabA: TabA.State
    var tabB: TabB.State
    var tabC: TabC.State
  }
  enum Action {
    case tabA(TabA.Action)
    case tabB(TabB.Action)
    case tabC(TabC.Action)
  }
  var body: some ReducerProtocolOf<Self> {
    Scope(state: \.tabA, action: /Action.tabA) {
      TabA()
    }
    Scope(state: \.tabB, action: /Action.tabB) {
      TabB()
    }
    Scope(state: \.tabC, action: /Action.tabC) {
      TabC()
    }
  }
}


func foo() {

  let statement1 = ReducerBuilder<App.State, App.Action>.buildExpression(
    Scope(state: \.tabA, action: /App.Action.tabA) {
      TabA()
    }
  )
  let block1 = ReducerBuilder<App.State, App.Action>.buildPartialBlock(first: statement1)
  let statement2 = ReducerBuilder<App.State, App.Action>.buildExpression(
    Scope(state: \.tabB, action: /App.Action.tabB) {
      TabB()
    }
  )
  let block2 = ReducerBuilder<App.State, App.Action>.buildPartialBlock(accumulated: block1, next: statement2)
}

//let partialBlock = ReducerBuilder.buildPartialBlock(
//  first: Scope(state: \.tabA, action: /App.Action.tabA) {
//    TabA()
//  }
//)

func tryOutApp() {
//  var state = App.State()
//  App().reduce(into: &state, action: <#T##ReducerProtocol.Action#>)
}

//let _appReducer: Reducer<App.State, App.Action, Void> = Reducer(App())


import Combine
func somePublisher() {
  let x: some Publisher<Int, Never> = Just(1)
  x.map { $0 + 1 }
}




struct TabAState {}
enum TabAAction {}
struct TabAEnvironment {}
let tabAReducer = Reducer<TabAState, TabAAction, TabAEnvironment> { _, _, _ in .none }

struct TabBState {}
enum TabBAction {}
struct TabBEnvironment {}
let tabBReducer = Reducer<TabBState, TabBAction, TabBEnvironment> { _, _, _ in .none }

struct TabCState {}
enum TabCAction {}
struct TabCEnvironment {}
let tabCReducer = Reducer<TabCState, TabCAction, TabCEnvironment> { _, _, _ in .none }

struct AppState {
  var tabA: TabAState
  var tabB: TabBState
  var tabC: TabCState
}
enum AppAction {
  case tabA(TabAAction)
  case tabB(TabBAction)
  case tabC(TabCAction)
}
enum AppEnvironment {}

let appReducer = Reducer<AppState, AppAction, AppEnvironment>.combine(
  tabAReducer
    .pullback(
      state: \.tabA,
      action: /AppAction.tabA,
      environment: { _ in .init() }
    )
)
