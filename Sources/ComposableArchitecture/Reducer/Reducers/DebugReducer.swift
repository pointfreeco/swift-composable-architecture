extension ReducerProtocol {
  /// Enhances a reducer with debug logging of received actions and state mutations.
  ///
  /// > Note: Printing is only done in `DEBUG` configurations.
  ///
  /// - Parameters:
  ///   - prefix: A string that will prefix all debug messages.
  ///     function and a background queue.
  /// - Returns: A reducer that prints debug messages for all received actions.
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

  /// Enhances a reducer with debug logging of received actions and state mutations.
  ///
  /// > Note: Printing is only done in `DEBUG` configurations.
  ///
  /// - Parameters:
  ///   - prefix: A string with which to prefix all debug messages.
  ///   - toChildState: A function that filters state to be printed.
  ///   - toChildAction: A case path that filters actions to be printed.
  /// - Returns: A reducer that prints debug messages for all received, filtered actions.
  @inlinable
  public func debug<ChildState, ChildAction>(
    _ prefix: String = "",
    state toChildState: @escaping (State) -> ChildState,
    action toChildAction: @escaping (Action) -> ChildAction?,
    actionFormat: ActionFormat = .prettyPrint
  ) -> _DebugReducer<Self, ChildState, ChildAction> {
    .init(
      base: self,
      prefix: prefix,
      state: toChildState,
      action: toChildAction,
      actionFormat: actionFormat
    )
  }
}

/// Determines how the string description of an action should be printed when using the
/// ``ReducerProtocol/debug(_:state:action:actionFormat:)`` higher-order reducer.
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

// TODO: Should this really be a dependency? (Or should it remain configuration?)
//       If so, should it be a more general `logger` that we expect users to use in their reducers?
// TODO: Should this dependency be an `any DebugLogger`?
extension DependencyValues {
  public var debugLogger: @Sendable (String) async -> Void {
    get { self[DebugLoggerKey.self] }
    set { self[DebugLoggerKey.self] = newValue }
  }

  private enum DebugLoggerKey: LiveDependencyKey {
    public static let liveValue: @Sendable (String) async -> Void = { print($0) }
    public static let testValue: @Sendable (String) async -> Void = { print($0) }
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
        .fireAndForget { [actionFormat] in
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
