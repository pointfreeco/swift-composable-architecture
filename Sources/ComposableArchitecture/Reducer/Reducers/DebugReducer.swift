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

  public static var actionLabels: Self {
    Self { receivedAction, _, _ in
      print("received action: \(debugCaseOutput(receivedAction))")
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

  #if DEBUG
    public func reduce(
      into state: inout Base.State, action: Base.Action
    ) -> Effect<Base.Action> {
      if let printer = self.printer {
        return withSharedChangeTracking { changeTracker in
          let oldState = state
          let effects = self.base.reduce(into: &state, action: action)
          return withEscapedDependencies { continuation in
            effects.merge(
              with: .publisher { [newState = state, queue = printer.queue] in
                Deferred<Empty<Action, Never>> {
                  queue.async {
                    continuation.yield {
                      changeTracker.assert {
                        printer.printChange(
                          receivedAction: action, oldState: oldState, newState: newState
                        )
                      }
                    }
                  }
                  return Empty()
                }
              }
            )
          }
        }
      }
      return self.base.reduce(into: &state, action: action)
    }
  #else
    @inlinable
    public func reduce(
      into state: inout Base.State, action: Base.Action
    ) -> Effect<Base.Action> {
      return self.base.reduce(into: &state, action: action)
    }
  #endif
}
