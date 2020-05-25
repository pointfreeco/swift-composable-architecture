import CasePaths
import Dispatch

extension Reducer {
  /// Prints debug messages describing all received actions and state mutations.
  ///
  /// Printing is only done in debug (`#if DEBUG`) builds.
  ///
  /// - Parameters:
  ///   - prefix: A string with which to prefix all debug messages.
  ///   - toDebugEnvironment: A function that transforms an environment into a debug environment by
  ///     describing a print function and a queue to print from. Defaults to a function that ignores
  ///     the environment and returns a default `DebugEnvironment` that uses Swift's `print`
  ///     function and a background queue.
  /// - Returns: A reducer that prints debug messages for all received actions.
  public func debug(
    _ prefix: String = "",
    environment toDebugEnvironment: @escaping (Environment) -> DebugEnvironment = { _ in
      DebugEnvironment()
    }
  ) -> Reducer {
    self.debug(prefix, state: { $0 }, action: .self, environment: toDebugEnvironment)
  }

  /// Prints debug messages describing all received actions.
  ///
  /// Printing is only done in debug (`#if DEBUG`) builds.
  ///
  /// - Parameters:
  ///   - prefix: A string with which to prefix all debug messages.
  ///   - toDebugEnvironment: A function that transforms an environment into a debug environment by
  ///     describing a print function and a queue to print from. Defaults to a function that ignores
  ///     the environment and returns a default `DebugEnvironment` that uses Swift's `print`
  ///     function and a background queue.
  /// - Returns: A reducer that prints debug messages for all received actions.
  public func debugActions(
    _ prefix: String = "",
    environment toDebugEnvironment: @escaping (Environment) -> DebugEnvironment = { _ in
      DebugEnvironment()
    }
  ) -> Reducer {
    self.debug(prefix, state: { _ in () }, action: .self, environment: toDebugEnvironment)
  }

  /// Prints debug messages describing all received local actions and local state mutations.
  ///
  /// Printing is only done in debug (`#if DEBUG`) builds.
  ///
  /// - Parameters:
  ///   - prefix: A string with which to prefix all debug messages.
  ///   - toLocalState: A function that filters state to be printed.
  ///   - toLocalAction: A case path that filters actions that are printed.
  ///   - toDebugEnvironment: A function that transforms an environment into a debug environment by
  ///     describing a print function and a queue to print from. Defaults to a function that ignores
  ///     the environment and returns a default `DebugEnvironment` that uses Swift's `print`
  ///     function and a background queue.
  /// - Returns: A reducer that prints debug messages for all received actions.
  public func debug<LocalState, LocalAction>(
    _ prefix: String = "",
    state toLocalState: @escaping (State) -> LocalState,
    action toLocalAction: CasePath<Action, LocalAction>,
    environment toDebugEnvironment: @escaping (Environment) -> DebugEnvironment = { _ in
      DebugEnvironment()
    }
  ) -> Reducer {
    #if DEBUG
      return .init { state, action, environment in
        let previousState = toLocalState(state)
        let effects = self.run(&state, action, environment)
        guard let localAction = toLocalAction.extract(from: action) else { return effects }
        let nextState = toLocalState(state)
        let debugEnvironment = toDebugEnvironment(environment)
        return .concatenate(
          .fireAndForget {
            debugEnvironment.queue.async {
              let actionOutput = debugOutput(localAction).indent(by: 2)
              let stateOutput =
                debugDiff(previousState, nextState).map { "\($0)\n" } ?? "  (No state changes)"
              debugEnvironment.printer(
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
      }
    #else
      return self
    #endif
  }
}

/// An environment for debug-printing reducers.
public struct DebugEnvironment {
  public var printer: (String) -> Void
  public var queue: DispatchQueue

  public init(
    printer: @escaping (String) -> Void = { print($0) },
    queue: DispatchQueue
  ) {
    self.printer = printer
    self.queue = queue
  }

  public init(
    printer: @escaping (String) -> Void = { print($0) }
  ) {
    self.init(printer: printer, queue: _queue)
  }
}

private let _queue = DispatchQueue(
  label: "co.pointfree.ComposableArchitecture.DebugEnvironment",
  qos: .background
)
