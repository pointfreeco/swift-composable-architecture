import CasePaths

public protocol _Reducer {
  associatedtype State
  associatedtype Action

  func reduce(into state: inout State, action: Action) -> Effect<Action, Never>
}

public enum Reducers {}

public struct AnyReducer<State, Action>: _Reducer {
  let reducer: (inout State, Action) -> Effect<Action, Never>

  public init(_ reducer: @escaping (inout State, Action) -> Effect<Action, Never>) {
    self.reducer = reducer
  }

  public func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    self.reducer(&state, action)
  }
}

extension _Reducer {
  func eraseToAnyReducer() -> AnyReducer<State, Action> {
    .init(self.reduce(into:action:))
  }
}

extension Reducers {
  public struct Empty<State, Action>: _Reducer {
    public init() {}

    public func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
      return .none
    }
  }
}

extension _Reducer {
  public static var empty: Reducers.Empty<State, Action> {
    .init()
  }
}

extension Reducers {
  public struct Combined<Reducer1, Reducer2>: _Reducer
  where
    Reducer1: _Reducer,
    Reducer2: _Reducer,
    Reducer1.State == Reducer2.State,
    Reducer1.Action == Reducer2.Action
  {
    public let reducer1: Reducer1
    public let reducer2: Reducer2

    public func reduce(into state: inout Reducer1.State, action: Reducer1.Action)
    -> Effect<Reducer1.Action, Never> {
      .merge(
        self.reducer1.reduce(into: &state, action: action),
        self.reducer2.reduce(into: &state, action: action)
      )
    }
  }
}

extension _Reducer {
  public func combined<Other>(with other: Other) -> Reducers.Combined<Self, Other>
  where Other: _Reducer, Other.State == Self.State, Other.Action == Self.Action {
    .init(reducer1: self, reducer2: other)
  }
}

extension Reducers {
  public struct Pullback<LocalReducer, State, Action>: _Reducer
  where LocalReducer: _Reducer {
    public let localReducer: LocalReducer
    public let toLocalState: WritableKeyPath<State, LocalReducer.State>
    public let toLocalAction: CasePath<Action, LocalReducer.Action>

    public func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
      guard let localAction = toLocalAction.extract(from: action) else { return .none }
      return self.localReducer.reduce(into: &state[keyPath: toLocalState], action: localAction)
        .map(toLocalAction.embed)
        .eraseToEffect()
    }
  }
}

extension _Reducer {
  public func pullback<GlobalState, GlobalAction>(
    state toLocalState: WritableKeyPath<GlobalState, Self.State>,
    action toLocalAction: CasePath<GlobalAction, Self.Action>
  ) -> Reducers.Pullback<Self, GlobalState, GlobalAction> {
    .init(localReducer: self, toLocalState: toLocalState, toLocalAction: toLocalAction)
  }
}

// store.environment(\.apiClient.endpoint) { _ in Effect(value: .success(1)) } <-
// reducer.environment(\.apiClient.endpoint) { _ in Effect(value: .success(1)) }

// @Dependency
// @EnvironmentDependecy

// dependencies as actors
// @MainActor class Store
