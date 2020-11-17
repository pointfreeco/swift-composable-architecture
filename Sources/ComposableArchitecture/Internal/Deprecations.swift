import Combine

// NB: Deprecated after 0.9.0:

extension Store {
  @available(*, deprecated, renamed: "publisherScope(state:)")
  public func scope<P: Publisher, LocalState>(
    state toLocalState: @escaping (AnyPublisher<State, Never>) -> P
  ) -> AnyPublisher<Store<LocalState, Action>, Never>
  where P.Output == LocalState, P.Failure == Never {
    self.publisherScope(state: toLocalState)
  }

  @available(*, deprecated, renamed: "publisherScope(state:action:)")
  public func scope<P: Publisher, LocalState, LocalAction>(
    state toLocalState: @escaping (AnyPublisher<State, Never>) -> P,
    action fromLocalAction: @escaping (LocalAction) -> Action
  ) -> AnyPublisher<Store<LocalState, LocalAction>, Never>
  where P.Output == LocalState, P.Failure == Never {
    self.publisherScope(state: toLocalState, action: fromLocalAction)
  }
}

// NB: Deprecated after 0.6.0:

extension Reducer {
  @available(*, deprecated, renamed: "optional()")
  public var optional: Reducer<State?, Action, Environment> {
    self.optional()
  }
}

// NB: Deprecated after 0.1.4:

extension Reducer {
  @available(*, unavailable, renamed: "debug(_:environment:)")
  public func debug(
    prefix: String,
    environment toDebugEnvironment: @escaping (Environment) -> DebugEnvironment = { _ in
      DebugEnvironment()
    }
  ) -> Reducer {
    self.debug(prefix, state: { $0 }, action: .self, environment: toDebugEnvironment)
  }

  @available(*, unavailable, renamed: "debugActions(_:environment:)")
  public func debugActions(
    prefix: String,
    environment toDebugEnvironment: @escaping (Environment) -> DebugEnvironment = { _ in
      DebugEnvironment()
    }
  ) -> Reducer {
    self.debug(prefix, state: { _ in () }, action: .self, environment: toDebugEnvironment)
  }

  @available(*, unavailable, renamed: "debug(_:state:action:environment:)")
  public func debug<LocalState, LocalAction>(
    prefix: String,
    state toLocalState: @escaping (State) -> LocalState,
    action toLocalAction: CasePath<Action, LocalAction>,
    environment toDebugEnvironment: @escaping (Environment) -> DebugEnvironment = { _ in
      DebugEnvironment()
    }
  ) -> Reducer {
    self.debug(prefix, state: toLocalState, action: toLocalAction, environment: toDebugEnvironment)
  }
}

extension WithViewStore {
  @available(*, unavailable, renamed: "debug(_:)")
  public func debug(prefix: String) -> Self {
    self.debug(prefix)
  }
}

// NB: Deprecated after 0.1.3:

extension Effect {
  @available(*, unavailable, renamed: "run")
  public static func async(
    _ work: @escaping (Effect.Subscriber) -> Cancellable
  ) -> Self {
    self.run(work)
  }
}

extension Effect where Failure == Swift.Error {
  @available(*, unavailable, renamed: "catching")
  public static func sync(_ work: @escaping () throws -> Output) -> Self {
    self.catching(work)
  }
}
