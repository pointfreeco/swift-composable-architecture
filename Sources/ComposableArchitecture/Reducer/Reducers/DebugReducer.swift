extension ReducerProtocol {
  /// Enhances a reducer with debug logging of received actions and state mutations.
  ///
  /// > Note: Printing is only done in `DEBUG` configurations.
  ///
  /// - Returns: A reducer that prints debug messages for all received actions.
  @inlinable
  public func debug() -> _DebugReducer<Self, CustomDumpDebugStrategy> {
    _DebugReducer(base: self, strategy: .customDump)
  }

  /// Enhances a reducer with debug logging of received actions and state mutations for the given
  /// ``DebugStrategy``.
  ///
  /// > Note: Printing is only done in `DEBUG` configurations.
  ///
  /// - Parameter strategy: A strategy for printing debug messages.
  /// - Returns: A reducer that prints debug messages for all received actions.
  @inlinable
  public func debug<Strategy: DebugStrategy>(
    _ strategy: Strategy?
  ) -> ReducerBuilder<State, Action>._Conditional<_DebugReducer<Self, Strategy>, Self> {
    strategy.map { .first(_DebugReducer(base: self, strategy: $0)) } ?? .second(self)
  }
}

public protocol DebugStrategy {
  func debug<Action, State>(receivedAction: Action, oldState: State, newState: State)
}

extension DebugStrategy where Self == CustomDumpDebugStrategy {
  public static var customDump: Self { Self() }
}

public struct CustomDumpDebugStrategy: DebugStrategy {
  public func debug<Action, State>(receivedAction: Action, oldState: State, newState: State) {
    var target = ""
    target.write("received action:\n")
    CustomDump.customDump(receivedAction, to: &target, indent: 2)
    target.write("\n")
    target.write(diff(oldState, newState).map { "\($0)\n" } ?? "  (No state changes)\n")
    print(target)
  }
}

extension DebugStrategy where Self == ActionLabelsDebugStrategy {
  public static var actionLabels: Self { Self() }
}

public struct ActionLabelsDebugStrategy: DebugStrategy {
  public func debug<Action, State>(receivedAction: Action, oldState: State, newState: State) {
    print("received action: \(debugCaseOutput(receivedAction))")
  }
}

public struct _DebugReducer<Base: ReducerProtocol, Strategy: DebugStrategy>: ReducerProtocol {
  @usableFromInline
  let base: Base

  @usableFromInline
  let strategy: Strategy

  @inlinable
  init(base: Base, strategy: Strategy) {
    self.base = base
    self.strategy = strategy
  }

  @usableFromInline
  @Dependency(\.context) var context

  @inlinable
  public func reduce(
    into state: inout Base.State, action: Base.Action
  ) -> Effect<Base.Action, Never> {
    #if DEBUG
      if self.context != .test {
        let oldState = state
        let effects = self.base.reduce(into: &state, action: action)
        return effects.merge(
          with: .fireAndForget { [newState = state] in
            self.strategy.debug(receivedAction: action, oldState: oldState, newState: newState)
          }
        )
      }
    #endif
    return self.base.reduce(into: &state, action: action)
  }
}
