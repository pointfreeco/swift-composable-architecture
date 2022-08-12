extension ReducerProtocol {
  @inlinable
  public func debug<LocalState, LocalAction>(
    _ prefix: String = "",
    state toLocalState: @escaping (State) -> LocalState,
    action toLocalAction: @escaping (Action) -> LocalAction?,
    actionFormat: ActionFormat = .prettyPrint
  ) -> _DebugReducer<Self, LocalState, LocalAction> {
    .init(
      base: self,
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
  ) -> _DebugReducer<Self, State, Action> {
    .init(
      base: self,
      prefix: prefix,
      state: { $0 },
      action: { $0 },
      actionFormat: actionFormat
    )
  }
}

public struct _DebugReducer<Base: ReducerProtocol, LocalState, LocalAction>: ReducerProtocol {
  @usableFromInline
  let base: Base

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
  init(
    base: Base,
    prefix: String,
    state toLocalState: @escaping (State) -> LocalState,
    action toLocalAction: @escaping (Action) -> LocalAction?,
    actionFormat: ActionFormat
  ) {
    self.base = base
    self.prefix = prefix
    self.toLocalState = toLocalState
    self.toLocalAction = toLocalAction
    self.actionFormat = actionFormat
  }

  @inlinable
  public func reduce(
    into state: inout Base.State, action: Base.Action
  ) -> Effect<Base.Action, Never> {
    #if DEBUG
      let previousState = self.toLocalState(state)
      let effects = self.base.reduce(into: &state, action: action)
      guard let localAction = self.toLocalAction(action) else { return effects }
      let nextState = self.toLocalState(state)
      return .merge(
        .fireAndForget { 
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
          await self.logger(
            """
            \(self.prefix.isEmpty ? "" : "\(self.prefix): ")received action:
            \(actionOutput)
            \(stateOutput)
            """
          )
        },
        effects
      )
    #else
      return self.base.reduce(into: &state, action: action)
    #endif
  }
}

/// Determines how the string description of an action should be printed when using the
/// ``ReducerProtocol/debug(_:state:action:actionFormat:)-5s1pa`` higher-order reducer.
public enum ActionFormat {
  /// Prints the action in a single line by only specifying the labels of the associated values:
  ///
  /// ```swift
  /// Action.screenA(.row(index:, action: .textChanged(query:)))
  /// ```
  ///
  case labelsOnly
  /// Prints the action in a multiline, pretty-printed format, including all the labels of
  /// any associated values, as well as the data held in the associated values:
  ///
  /// ```swift
  /// Action.screenA(
  ///   ScreenA.row(
  ///     index: 1,
  ///     action: RowAction.textChanged(
  ///       query: "Hi"
  ///     )
  ///   )
  /// )
  /// ```
  ///
  case prettyPrint
}

extension DependencyValues {
  // TODO: Should this be `any DebugLogger`?
  public var debugLogger: @Sendable (String) async -> Void {
    get { self[DebugLoggerKey.self] }
    set { self[DebugLoggerKey.self] = newValue }
  }

  private enum DebugLoggerKey: LiveDependencyKey {
    public static let liveValue: @Sendable (String) async -> Void = { print($0) }
    public static let testValue: @Sendable (String) async -> Void = { print($0) }
  }
}
