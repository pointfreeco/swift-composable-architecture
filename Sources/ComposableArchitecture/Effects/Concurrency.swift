@preconcurrency import Combine
import SwiftUI

extension Effect where Failure == Never {
  /// Wraps an asynchronous unit of work in an effect.
  ///
  /// This function is useful for executing work in an asynchronous context and capture the result
  /// in an ``Effect`` so that the reducer, a non-asynchronous context, can process it.
  ///
  /// For example, if your environment contains a dependency that exposes an `async` function, you
  /// can use ``Effect/task(priority:operation:)-4llhw`` to provide an asynchronous context for
  /// invoking that endpoint:
  ///
  /// ```swift
  /// struct FeatureEnvironment {
  ///   var numberFact: @Sendable (Int) async throws -> String
  /// }
  ///
  /// enum FeatureAction {
  ///   case factButtonTapped
  ///   case faceResponse(TaskResult<String>)
  /// }
  ///
  /// let featureReducer = Reducer<State, Action, Environment> { state, action, environment in
  ///   switch action {
  ///     case .factButtonTapped:
  ///       return .task { [number = state.number] in
  ///         await .factResponse(TaskResult { try await environment.numberFact(number) })
  ///       }
  ///
  ///     case .factResponse(.success(fact)):
  ///       // do something with fact
  ///
  ///     case .factResponse(.failure):
  ///       // handle error
  ///
  ///     ...
  ///   }
  /// }
  /// ```
  ///
  /// The above code sample makes use of ``TaskResult`` in order to automatically bundle the success
  /// or failure of the `numberFact` endpoint into a single type that can be sent in an action.
  ///
  /// The closure provided to ``Effect/task(priority:operation:catch:file:fileID:line:)`` is allowed
  /// to throw, but any non-cancellation errors thrown will cause a runtime warning when run in the
  /// simulator or on a device, and will cause a test failure in tests.
  ///
  /// - Parameters:
  ///   - priority: Priority of the underlying task. If `nil`, the priority will come from
  ///     `Task.currentPriority`.
  ///   - operation: The operation to execute.
  ///   - catch: An error handler, invoked if the operation throws an error.
  /// - Returns: An effect wrapping the given asynchronous work.
  public static func task(
    priority: TaskPriority? = nil,
    operation: @escaping @Sendable () async throws -> Output,
    catch handler: (@Sendable (Error) async -> Output)? = nil,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    Deferred<Publishers.HandleEvents<PassthroughSubject<Output, Failure>>> {
      let subject = PassthroughSubject<Output, Failure>()
      let task = Task(priority: priority) { @MainActor in
        defer { subject.send(completion: .finished) }
        do {
          try Task.checkCancellation()
          let output = try await operation()
          try Task.checkCancellation()
          subject.send(output)
        } catch is CancellationError {
          return
        } catch {
          guard let handler = handler else {
            var errorDump = ""
            customDump(error, to: &errorDump, indent: 2)
            runtimeWarning(
              """
              An 'Effect.task' returned from "%@:%d" threw an unhandled error:

              %@

              All non-cancellation errors must be explicitly handled via the 'catch' parameter on \
              'Effect.task', or via a 'do' block.
              """,
              [
                "\(fileID)",
                line,
                errorDump
              ],
              file: file,
              line: line
            )
            return
          }
          await subject.send(handler(error))
        }
      }
      return subject.handleEvents(receiveCancel: task.cancel)
    }
    .eraseToEffect()
  }

  /// Wraps an asynchronous unit of work that can emit any number of times in an effect.
  ///
  /// This effect is similar to ``Effect/task(priority:operation:)-4llhw`` except it is capable of
  /// emitting any number of times times, not just once.
  ///
  /// For example, if you had an async stream in your environment:
  ///
  /// ```swift
  /// struct FeatureEnvironment {
  ///   var events: @Sendable () -> AsyncStream<Event>
  /// }
  /// ```
  ///
  /// Then you could attach to it in a `run` effect by using `for await` and sending each output of
  /// the stream back into the system:
  ///
  /// ```swift
  /// case .startButtonTapped:
  ///   return .run { send in
  ///     for await event in environment.events() {
  ///       send(.event(event))
  ///     }
  ///   }
  /// ```
  ///
  /// See ``Send`` for more information on how to use the `send` argument passed to `run`'s closure.
  ///
  /// The closure provided to ``Effect/run(priority:_:catch:file:fileID:line:)`` is allowed
  /// to throw, but any non-cancellation errors thrown will cause a runtime warning when run in the
  /// simulator or on a device, and will cause a test failure in tests.
  ///
  /// - Parameters:
  ///   - priority: Priority of the underlying task. If `nil`, the priority will come from
  ///     `Task.currentPriority`.
  ///   - operation: The operation to execute.
  ///   - catch: An error handler, invoked if the operation throws an error.
  /// - Returns: An effect wrapping the given asynchronous work.
  public static func run(
    priority: TaskPriority? = nil,
    _ operation: @escaping @Sendable (Send<Output>) async throws -> Void,
    catch handler: (@Sendable (Error, Send<Output>) async -> Void)? = nil,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    .run { subscriber in
      let task = Task(priority: priority) { @MainActor in
        defer { subscriber.send(completion: .finished) }
        let send = Send(send: { subscriber.send($0) })
        do {
          try await operation(send)
        } catch is CancellationError {
          return
        } catch {
          guard let handler = handler else {
            var errorDump = ""
            customDump(error, to: &errorDump, indent: 2)
            runtimeWarning(
              """
              An 'Effect.run' returned from "%@:%d" threw an unhandled error:

              %@

              All non-cancellation errors must be explicitly handled via the 'catch' parameter on \
              'Effect.run', or via a 'do' block.
              """,
              [
                "\(fileID)",
                line,
                errorDump
              ],
              file: file,
              line: line
            )
            return
          }
          await handler(error, send)
        }
      }
      return AnyCancellable {
        task.cancel()
      }
    }
  }

  /// Creates an effect that executes some work in the real world that doesn't need to feed data
  /// back into the store. If an error is thrown, the effect will complete and the error will be
  /// ignored.
  ///
  /// This effect is handy for executing some asynchronous work that your feature doesn't need to
  /// react to. One such example is analytics:
  ///
  /// ```swift
  /// case .buttonTapped:
  ///   return .fireAndForget {
  ///     try await environment.analytics.track("Button Tapped")
  ///   }
  /// ```
  ///
  /// The closure provided to ``Effect/fireAndForget(priority:_:)`` is allowed to throw, and any
  /// error thrown will be ignored.
  ///
  /// - Parameters:
  ///   - priority: Priority of the underlying task. If `nil`, the priority will come from
  ///     `Task.currentPriority`.
  ///   - work: A closure encapsulating some work to execute in the real world.
  /// - Returns: An effect.
  public static func fireAndForget(
    priority: TaskPriority? = nil,
    _ work: @escaping @Sendable () async throws -> Void
  ) -> Self {
    Effect<Void, Never>.task(priority: priority) { try? await work() }
      .fireAndForget()
  }
}

/// A type that can send actions back into the system when used from
/// ``Effect/run(priority:_:catch:file:fileID:line:)``.
///
/// This type implements [`callAsFunction`][callAsFunction] so that you invoke it as a function
/// rather than calling methods on it:
///
/// ```swift
/// return .run { send in
///   send(.started)
///   defer { send(.finished) }
///   for await event in environment.events {
///     send(.event(event))
///   }
/// }
/// ```
///
/// You can also send actions with animation:
///
/// ```swift
/// send(.started, animation: .spring())
/// defer { send(.finished, animation: .default) }
/// ```
///
/// See ``Effect/run(priority:_:)`` for more information on how to use this value to construct
/// effects that can emit any number of times in an asynchronous context.
///
/// [callAsFunction]: https://docs.swift.org/swift-book/ReferenceManual/Declarations.html#ID622
@MainActor
public struct Send<Action> {
  fileprivate let send: @Sendable (Action) -> Void

  public func callAsFunction(_ action: Action) {
    self.send(action)
  }

  public func callAsFunction(_ action: Action, animation: Animation? = nil) {
    withAnimation(animation) {
      self.send(action)
    }
  }
}

extension Send: Sendable where Action: Sendable {}
