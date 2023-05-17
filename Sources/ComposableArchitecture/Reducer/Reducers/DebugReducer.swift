extension ReducerProtocol {
  #if swift(>=5.8)
    /// Enhances a reducer with debug logging of received actions and state mutations for the given
    /// printer.
    ///
    /// > Note: Printing is only done in `DEBUG` configurations.
    ///
    /// - Parameter printer: A printer for printing debug messages.
    /// - Returns: A reducer that prints debug messages for all received actions.
    @inlinable
    @warn_unqualified_access
    @_documentation(visibility:public)
    public func _printChanges(
      _ printer: _ReducerPrinter<State, Action>? = .customDump
    ) -> _PrintChangesReducer<Self> {
      _PrintChangesReducer<Self>(base: self, printer: printer)
    }
  #else
    @inlinable
    @warn_unqualified_access
    public func _printChanges(
      _ printer: _ReducerPrinter<State, Action>? = .customDump
    ) -> _PrintChangesReducer<Self> {
      _PrintChangesReducer<Self>(base: self, printer: printer)
    }
  #endif
}

public struct _ReducerPrinter<State, Action> {
  private let _printChange: (_ receivedAction: Action, _ oldState: State, _ newState: State) -> Void

  public init(
    printChange: @escaping (_ receivedAction: Action, _ oldState: State, _ newState: State) -> Void
  ) {
    self._printChange = printChange
  }

  public func printChange(receivedAction: Action, oldState: State, newState: State) {
    self._printChange(receivedAction, oldState, newState)
  }
}

extension _ReducerPrinter {
  public static var customDump: Self {
    Self.customDump { actionDump, stateDiff in
      var target = ""
      target.write("received action:\n")
      target.write(actionDump)
      target.write("\n")
      target.write(stateDiff.map { "\($0)\n" } ?? "  (No state changes)\n")
      print(target)
    }
  }

  public static var actionLabels: Self {
    Self.actionLabels {
      print("received action: \($0)")
    }
  }

  public static func customDump(printer: @escaping (_ actionDump: String, _ stateDiff: String?) -> Void) -> Self {
    Self { receivedAction, oldState, newState in
      var actionDump = ""
      CustomDump.customDump(receivedAction, to: &actionDump, indent: 2)
      let stateDiff = diff(oldState, newState)
      printer(actionDump, stateDiff)
    }
  }

  public static func actionLabels(printer: @escaping (_ action: String) -> Void) -> Self {
    Self { receivedAction, _, _ in
      printer(debugCaseOutput(receivedAction))
    }
  }
}

public struct _PrintChangesReducer<Base: ReducerProtocol>: ReducerProtocol {
  @usableFromInline
  let base: Base

  @usableFromInline
  let printer: _ReducerPrinter<Base.State, Base.Action>?

  @usableFromInline
  init(base: Base, printer: _ReducerPrinter<Base.State, Base.Action>?) {
    self.base = base
    self.printer = printer
  }

  @inlinable
  public func reduce(
    into state: inout Base.State, action: Base.Action
  ) -> EffectTask<Base.Action> {
    #if DEBUG
      if let printer = self.printer {
        let oldState = state
        let effects = self.base.reduce(into: &state, action: action)
        return effects.merge(
          with: .fireAndForget { [newState = state] in
            printer.printChange(receivedAction: action, oldState: oldState, newState: newState)
          }
        )
      }
    #endif
    return self.base.reduce(into: &state, action: action)
  }
}
