extension ReducerProtocol {
  /// Enhances a reducer with debug logging of received actions and state mutations.
  ///
  /// > Note: Printing is only done in `DEBUG` configurations.
  ///
  /// - Returns: A reducer that prints debug messages for all received actions.
  @inlinable
  public func _printChanges() -> _PrintChangesReducer<Self, _CustomDumpPrinter> {
    _PrintChangesReducer(base: self, printer: .customDump)
  }

  /// Enhances a reducer with debug logging of received actions and state mutations for the given
  /// printer.
  ///
  /// > Note: Printing is only done in `DEBUG` configurations.
  ///
  /// - Parameter printer: A printer for printing debug messages.
  /// - Returns: A reducer that prints debug messages for all received actions.
  @inlinable
  public func _printChanges<Printer: _ReducerPrinter>(
    _ printer: Printer?
  ) -> ReducerBuilder<State, Action>._Conditional<_PrintChangesReducer<Self, Printer>, Self> {
    printer.map { .first(_PrintChangesReducer(base: self, printer: $0)) } ?? .second(self)
  }
}

public protocol _ReducerPrinter {
  func printChange<Action, State>(receivedAction: Action, oldState: State, newState: State)
}

extension _ReducerPrinter where Self == _CustomDumpPrinter {
  public static var customDump: Self { Self() }
}

public struct _CustomDumpPrinter: _ReducerPrinter {
  public func printChange<Action, State>(receivedAction: Action, oldState: State, newState: State) {
    var target = ""
    target.write("received action:\n")
    CustomDump.customDump(receivedAction, to: &target, indent: 2)
    target.write("\n")
    target.write(diff(oldState, newState).map { "\($0)\n" } ?? "  (No state changes)\n")
    print(target)
  }
}

extension _ReducerPrinter where Self == _ActionLabelsPrinter {
  public static var actionLabels: Self { Self() }
}

public struct _ActionLabelsPrinter: _ReducerPrinter {
  public func printChange<Action, State>(receivedAction: Action, oldState: State, newState: State) {
    print("received action: \(debugCaseOutput(receivedAction))")
  }
}

public struct _PrintChangesReducer<
  Base: ReducerProtocol, Printer: _ReducerPrinter
>: ReducerProtocol {
  @usableFromInline
  let base: Base

  @usableFromInline
  let printer: Printer

  @usableFromInline
  init(base: Base, printer: Printer) {
    self.base = base
    self.printer = printer
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
            self.printer.printChange(receivedAction: action, oldState: oldState, newState: newState)
          }
        )
      }
    #endif
    return self.base.reduce(into: &state, action: action)
  }
}
