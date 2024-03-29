import Combine
import Dispatch

extension Reducer {
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

private let printQueue = DispatchQueue(label: "co.pointfree.swift-composable-architecture.printer")

public struct _ReducerPrinter<State, Action> {
  private let _printChange: (_ receivedAction: Action, _ oldState: State, _ newState: State) -> Void
  @usableFromInline
  let queue: DispatchQueue

  public init(
    printChange: @escaping (_ receivedAction: Action, _ oldState: State, _ newState: State) -> Void,
    queue: DispatchQueue? = nil
  ) {
    self._printChange = printChange
    self.queue = queue ?? printQueue
  }

  public func printChange(receivedAction: Action, oldState: State, newState: State) {
    self._printChange(receivedAction, oldState, newState)
  }
}

extension _ReducerPrinter {
  /// the default printer
  public static var customDump: Self {
    Self { receivedAction, oldState, newState in
      var target = ""
      target.write("received action:\n")
      CustomDump.customDump(receivedAction, to: &target, indent: 2)
      target.write("\n")
      target.write(diff(oldState, newState).map { "\($0)\n" } ?? "  (No state changes)\n")
      print(target)
    }
  }

  /// Prints just the labels of the actions without the changes
  public static var actionLabels: Self {
    Self { receivedAction, _, _ in
      print("received action: \(debugCaseOutput(receivedAction))")
    }
  }
}

extension _ReducerPrinter {
  /// Prints only the actions that you want to see.
  ///
  ///  ## Example Usage
  ///  ```swift
  /// // only print if the action is `.childPlayer(.updateProgress)`
  ///  MyReducer()
  ///    ._printChanges(
  ///      .filtered(
  ///        actions: { action in
  ///          switch action {
  ///            case .childPlayer(.updateProgress):
  ///              return false
  ///            default: return true
  ///          }
  ///        }
  ///      )
  ///    )
  /// ```
  /// - Parameter includingActions: a closure describing the action to include.
  /// - Returns: the `_ReducerPrinter`
  public static func filtered(actions includingActions: @escaping (Action) -> Bool) -> Self {
    Self { receivedAction, oldState, newState in
      if includingActions(receivedAction) {
        // repeated from _ReducerPrinter.customDump
        // TODO: Remove code duplication
        var target = ""
        target.write("received action:\n")
        CustomDump.customDump(receivedAction, to: &target, indent: 2)
        target.write("\n")
        target.write(diff(oldState, newState).map { "\($0)\n" } ?? "  (No state changes)\n")
        print(target)
      }
    }
  }
  
  /// Prints only the changes you want to see
  ///
  /// ## Example Usage
  /// ```swift
  /// MyReducer()
  ///   ._printChanges(
  ///     .filtered(
  ///       changes: { oldState, newState in
  ///         // only print when sheetPlayer changes
  ///         oldState.sheetPlayer != newState.sheetPlayer
  ///       }
  ///     )
  ///   )
  /// ```
  /// - Parameter includingChanges: a closure describing the changes to include
  /// - Returns: the `_ReducerPrinter`
  public static func filtered(changes includingChanges: @escaping (_ oldState: State, _ newState: State) -> Bool) -> Self {
    Self { receivedAction, oldState, newState in
      if includingChanges(oldState, newState) {
        // repeated from _ReducerPrinter.customDump
        // TODO: Remove code duplication
        var target = ""
        target.write("received action:\n")
        CustomDump.customDump(receivedAction, to: &target, indent: 2)
        target.write("\n")
        target.write(diff(oldState, newState).map { "\($0)\n" } ?? "  (No state changes)\n")
        print(target)
      }
    }
  }
}

public struct _PrintChangesReducer<Base: Reducer>: Reducer {
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
  ) -> Effect<Base.Action> {
    #if DEBUG
      if let printer = self.printer {
        let oldState = state
        let effects = self.base.reduce(into: &state, action: action)
        return effects.merge(
          with: .publisher { [newState = state, queue = printer.queue] in
            Deferred<Empty<Action, Never>> {
              queue.async {
                printer.printChange(receivedAction: action, oldState: oldState, newState: newState)
              }
              return Empty()
            }
          }
        )
      }
    #endif
    return self.base.reduce(into: &state, action: action)
  }
}
