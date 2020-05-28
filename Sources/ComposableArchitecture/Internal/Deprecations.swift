import Combine

// NB: Deprecated after 0.1.4:

extension Reducer {
  @available(*, deprecated, renamed: "debug(_:environment:)")
  public func debug(
    prefix: String,
    environment toDebugEnvironment: @escaping (Environment) -> DebugEnvironment = { _ in
      DebugEnvironment()
    }
  ) -> Reducer {
    self.debug(prefix, state: { $0 }, action: .self, environment: toDebugEnvironment)
  }

  @available(*, deprecated, renamed: "debugActions(_:environment:)")
  public func debugActions(
    prefix: String,
    environment toDebugEnvironment: @escaping (Environment) -> DebugEnvironment = { _ in
      DebugEnvironment()
    }
  ) -> Reducer {
    self.debug(prefix, state: { _ in () }, action: .self, environment: toDebugEnvironment)
  }

  @available(*, deprecated, renamed: "debug(_:state:action:environment:)")
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
  @available(*, deprecated, renamed: "debug(_:)")
  public func debug(prefix: String) -> Self {
    self.debug(prefix)
  }
}

// NB: Deprecated after 0.1.3:

extension Effect {
  @available(*, deprecated, renamed: "run")
  public static func async(
    _ work: @escaping (Effect.Subscriber) -> Cancellable
  ) -> Self {
    self.run(work)
  }
}

extension Effect where Failure == Swift.Error {
  @available(*, deprecated, renamed: "catching")
  public static func sync(_ work: @escaping () throws -> Output) -> Self {
    self.catching(work)
  }
}
