import CombineSchedulers

extension _Reducer {
  public func debug<LocalState, LocalAction>(
    prefix: String = "",
    state toLocalState: @escaping (State) -> LocalState,
    action toLocalAction: @escaping (Action) -> LocalAction?,
    actionFormat: ActionFormat = .prettyPrint
  ) -> ReducerDebug<Self, LocalState, LocalAction> {
    .init(
      upstream: self,
      prefix: prefix,
      state: toLocalState,
      action: toLocalAction,
      actionFormat: actionFormat
    )
  }

  public func debug(
    _ prefix: String = "",
    actionFormat: ActionFormat = .prettyPrint
  ) -> ReducerDebug<Self, State, Action> {
    .init(
      upstream: self,
      prefix: prefix,
      state: { $0 },
      action: { $0 },
      actionFormat: actionFormat
    )
  }
}

public struct ReducerDebug<Upstream, LocalState, LocalAction>: _Reducer
where
  Upstream: _Reducer
{
  public let upstream: Upstream

  public let prefix: String
  public let toLocalState: (State) -> LocalState
  public let toLocalAction: (Action) -> LocalAction?
  public let actionFormat: ActionFormat

  @Dependency(\.debugLogger) var logger
  @Dependency(\.debugLoggingQueue) var queue

  init(
    upstream: Upstream,
    prefix: String = "",
    state toLocalState: @escaping (State) -> LocalState,
    action toLocalAction: @escaping (Action) -> LocalAction?,
    actionFormat: ActionFormat = .prettyPrint
  ) {
    self.upstream = upstream
    self.prefix = prefix
    self.toLocalState = toLocalState
    self.toLocalAction = toLocalAction
    self.actionFormat = actionFormat
  }

  public func reduce(
    into state: inout Upstream.State,
    action: Upstream.Action
  ) -> Effect<Upstream.Action, Never> {
    #if DEBUG
    let previousState = toLocalState(state)
    let effects = self.upstream.reduce(into: &state, action: action)
    guard let localAction = toLocalAction(action) else { return effects }
    let nextState = toLocalState(state)
    return .merge(
      .fireAndForget {
        self.queue.schedule {
          var actionOutput = ""
          if actionFormat == .prettyPrint {
            customDump(localAction, to: &actionOutput, indent: 2)
          } else {
            actionOutput.write(debugCaseOutput(localAction).indent(by: 2))
          }
          let stateOutput =
            LocalState.self == Void.self
            ? ""
            : diff(previousState, nextState).map { "\($0)\n" } ?? "  (No state changes)\n"
          self.logger(
            """
            \(prefix.isEmpty ? "" : "\(prefix): ")received action:
            \(actionOutput)
            \(stateOutput)
            """
          )
        }
      },
      effects
    )
    #else
    return self.upstream.reduce(into: &state, action: action)
    #endif
  }
}

public enum DebugLoggingQueue: DependencyKey {
  public static let defaultValue = AnySchedulerOf<DispatchQueue>(_debugLoggingQueue)
  public static let testValue = AnySchedulerOf<DispatchQueue>.immediate
}
extension DependencyValues {
  public var debugLoggingQueue: AnySchedulerOf<DispatchQueue> {
    get { self[DebugLoggingQueue.self] }
    set { self[DebugLoggingQueue.self] = newValue }
  }
}

public enum DebugLogger: DependencyKey {
  public static let defaultValue: (String) -> Void = { print($0) }
  public static let testValue: (String) -> Void = { print($0) }
}
extension DependencyValues {
  public var debugLogger: (String) -> Void {
    get { self[DebugLogger.self] }
    set { self[DebugLogger.self] = newValue }
  }
}

public let _debugLoggingQueue = DispatchQueue(
  label: "co.pointfree.ComposableArchitecture.DebugEnvironment",
  qos: .utility
)
