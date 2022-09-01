extension ReducerProtocol {
  /// Enhances a reducer with debug logging of received actions and state mutations.
  ///
  /// > Note: Printing is only done in `DEBUG` configurations.
  ///
  /// - Parameters:
  ///   - prefix: A string that will prefix all debug messages.
  ///   - actionFormat: The format used to print actions.
  ///   - logger: A function that is used to print debug messages.
  /// - Returns: A reducer that prints debug messages for all received actions.
  @inlinable
  public func debug(
    _ prefix: String = "",
    actionFormat: ActionFormat = .prettyPrint,
    to logger: @escaping @Sendable (String) async -> Void = { print($0) }
  ) -> _DebugReducer<Self, State, Action> {
    self.debug(
      prefix,
      state: { $0 },
      action: { $0 },
      actionFormat: actionFormat,
      to: logger
    )
  }

  /// Enhances a reducer with debug logging of received actions and state mutations.
  ///
  /// > Note: Printing is only done in `DEBUG` configurations.
  ///
  /// - Parameters:
  ///   - prefix: A string with which to prefix all debug messages.
  ///   - toChildState: A function that filters state to be printed.
  ///   - toChildAction: A case path that filters actions to be printed.
  ///   - actionFormat: The format used to print actions.
  ///   - logger: A function that is used to print debug messages.
  /// - Returns: A reducer that prints debug messages for all received, filtered actions.
  @inlinable
  public func debug<ChildState, ChildAction>(
    _ prefix: String = "",
    state toChildState: @escaping (State) -> ChildState,
    action toChildAction: @escaping (Action) -> ChildAction?,
    actionFormat: ActionFormat = .prettyPrint,
    to logger: @escaping @Sendable (String) async -> Void = { print($0) }
  ) -> _DebugReducer<Self, ChildState, ChildAction> {
    .init(
      base: self,
      prefix: prefix,
      state: toChildState,
      action: toChildAction,
      actionFormat: actionFormat,
      logger: logger
    )
  }
}

/// Determines how the string description of an action should be printed when using the
/// ``ReducerProtocol/debug(_:state:action:actionFormat:to:)`` higher-order reducer.
public enum ActionFormat: Sendable {
  /// Prints the action in a single line by only specifying the labels of the associated values:
  ///
  /// ```swift
  /// Action.screenA(.row(index:, action: .textChanged(query:)))
  /// ```
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
  case prettyPrint
}

public struct _DebugReducer<Base: ReducerProtocol, DebugState, DebugAction>: ReducerProtocol {
  @usableFromInline
  let base: Base

  @usableFromInline
  let prefix: String

  @usableFromInline
  let toDebugState: (State) -> DebugState

  @usableFromInline
  let toDebugAction: (Action) -> DebugAction?

  @usableFromInline
  let actionFormat: ActionFormat

  @usableFromInline
  let logger: @Sendable (String) async -> Void

  @inlinable
  init(
    base: Base,
    prefix: String,
    state toDebugState: @escaping (State) -> DebugState,
    action toDebugAction: @escaping (Action) -> DebugAction?,
    actionFormat: ActionFormat,
    logger: @escaping @Sendable (String) async -> Void
  ) {
    self.base = base
    self.prefix = prefix
    self.toDebugState = toDebugState
    self.toDebugAction = toDebugAction
    self.actionFormat = actionFormat
    self.logger = logger
  }

  @inlinable
  public func reduce(
    into state: inout Base.State, action: Base.Action
  ) -> Effect<Base.Action, Never> {
    #if DEBUG
      let previousState = self.toDebugState(state)
      let effects = self.base.reduce(into: &state, action: action)
      guard let debugAction = self.toDebugAction(action) else { return effects }
      let nextState = self.toDebugState(state)
      return effects.merge(
        with: .fireAndForget { [actionFormat] in
          var actionOutput = ""
          if actionFormat == .prettyPrint {
            customDump(debugAction, to: &actionOutput, indent: 2)
          } else {
            actionOutput.write(debugCaseOutput(debugAction).indent(by: 2))
          }
          let stateOutput =
          DebugState.self == Void.self
          ? ""
          : diff(previousState, nextState).map { "\($0)\n" } ?? "  (No state changes)\n"
          await self.logger(
            """
            \(self.prefix.isEmpty ? "" : "\(self.prefix): ")received action:
            \(actionOutput)
            \(stateOutput)
            """
          )
        }
      )
    #else
      return self.base.reduce(into: &state, action: action)
    #endif
  }
}
