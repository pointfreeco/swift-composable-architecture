/*
 TODO: Explore more formulations:

 var body: some ReducerProtocol<State, Action> {
   Debug { // like clock.measure { ... }, testCase.measure { ... }
     R1()
     R2()
   }
 }

 var body: some ReducerProtocol<State, Action> {
   DebugAfter()
   ...
 }

 var body: some ReducerProtocol<State, Action> {
   ...
   DebugBefore()
 }
 */

extension ReducerProtocol {
  @inlinable
  public func debug<LocalState, LocalAction>(
    prefix: String = "",
    state toLocalState: @escaping (State) -> LocalState,
    action toLocalAction: @escaping (Action) -> LocalAction?,
    actionFormat: ActionFormat = .prettyPrint
  ) -> DebugReducer<Self, LocalState, LocalAction> {
    .init(
      upstream: self,
      prefix: prefix,
      state: toLocalState,
      action: toLocalAction,
      actionFormat: actionFormat
    )
  }

  @inlinable
  public func debug(
    _ prefix: String = "",
    actionFormat: ActionFormat = .prettyPrint
  ) -> DebugReducer<Self, State, Action> {
    .init(
      upstream: self,
      prefix: prefix,
      state: { $0 },
      action: { $0 },
      actionFormat: actionFormat
    )
  }
}

public struct DebugReducer<Upstream, LocalState, LocalAction>: ReducerProtocol
where Upstream: ReducerProtocol {
  public let upstream: Upstream

  @usableFromInline
  let prefix: String

  @usableFromInline
  let toLocalState: (State) -> LocalState

  @usableFromInline
  let toLocalAction: (Action) -> LocalAction?

  @usableFromInline
  let actionFormat: ActionFormat

  @usableFromInline
  @Dependency(\.debugLogger) var logger

  @usableFromInline
  @Dependency(\.debugLoggingQueue) var queue

  @usableFromInline
  init(
    upstream: Upstream,
    prefix: String,
    state toLocalState: @escaping (State) -> LocalState,
    action toLocalAction: @escaping (Action) -> LocalAction?,
    actionFormat: ActionFormat
  ) {
    self.upstream = upstream
    self.prefix = prefix
    self.toLocalState = toLocalState
    self.toLocalAction = toLocalAction
    self.actionFormat = actionFormat
  }

  @inlinable
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

extension DependencyValues {
  public var debugLogger: (String) -> Void {
    get { self[DebugLoggerKey.self] }
    set { self[DebugLoggerKey.self] = newValue }
  }

  public var debugLoggingQueue: AnySchedulerOf<DispatchQueue> {
    get { self[DebugLoggingQueueKey.self] }
    set { self[DebugLoggingQueueKey.self] = newValue }
  }

  private enum DebugLoggerKey: LiveDependencyKey {
    public static let liveValue: (String) -> Void = { print($0) }
    public static let testValue: (String) -> Void = { print($0) }
  }

  private enum DebugLoggingQueueKey: LiveDependencyKey {
    static let liveValue = AnySchedulerOf<DispatchQueue>(
      DispatchQueue(
        label: "co.pointfree.ComposableArchitecture.DebugReducer",
        qos: .utility
      )
    )
    static let testValue = AnySchedulerOf<DispatchQueue>.immediate
  }
}
