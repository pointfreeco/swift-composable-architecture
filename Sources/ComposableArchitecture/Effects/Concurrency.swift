import Combine
import SwiftUI

#if canImport(_Concurrency) && compiler(>=5.5.2)
  extension Effect {
    /// Wraps an asynchronous unit of work in an effect.
    ///
    /// This function is useful for executing work in an asynchronous context and capture the
    /// result in an ``Effect`` so that the reducer, a non-asynchronous context, can process it.
    ///
    /// ```swift
    /// Effect.task {
    ///   guard case let .some((data, _)) = try? await URLSession.shared
    ///     .data(from: .init(string: "http://numbersapi.com/42")!)
    ///   else {
    ///     return "Could not load"
    ///   }
    ///
    ///   return String(decoding: data, as: UTF8.self)
    /// }
    /// ```
    ///
    /// Note that due to the lack of tools to control the execution of asynchronous work in Swift,
    /// it is not recommended to use this function in reducers directly. Doing so will introduce
    /// thread hops into your effects that will make testing difficult. You will be responsible
    /// for adding explicit expectations to wait for small amounts of time so that effects can
    /// deliver their output.
    ///
    /// Instead, this function is most helpful for calling `async`/`await` functions from the live
    /// implementation of dependencies, such as `URLSession.data`, `MKLocalSearch.start` and more.
    ///
    /// - Parameters:
    ///   - priority: Priority of the underlying task. If `nil`, the priority will come from
    ///     `Task.currentPriority`.
    ///   - operation: The operation to execute.
    /// - Returns: An effect wrapping the given asynchronous work.
    public static func task(
      priority: TaskPriority? = nil,
      operation: @escaping @Sendable () async -> Output
    ) -> Self where Failure == Never {
      var task: Task<Void, Never>?
      return .future { callback in
        task = Task(priority: priority) { @MainActor in
          guard !Task.isCancelled else { return }
          let output = await operation()
          guard !Task.isCancelled else { return }
          callback(.success(output))
        }
      }
      .handleEvents(receiveCancel: { task?.cancel() })
      .eraseToEffect()
    }

    /// Wraps an asynchronous unit of work in an effect.
    ///
    /// This function is useful for executing work in an asynchronous context and capture the
    /// result in an ``Effect`` so that the reducer, a non-asynchronous context, can process it.
    ///
    /// ```swift
    /// Effect.task {
    ///   let (data, _) = try await URLSession.shared
    ///     .data(from: .init(string: "http://numbersapi.com/42")!)
    ///
    ///   return String(decoding: data, as: UTF8.self)
    /// }
    /// ```
    ///
    /// Note that due to the lack of tools to control the execution of asynchronous work in Swift,
    /// it is not recommended to use this function in reducers directly. Doing so will introduce
    /// thread hops into your effects that will make testing difficult. You will be responsible
    /// for adding explicit expectations to wait for small amounts of time so that effects can
    /// deliver their output.
    ///
    /// Instead, this function is most helpful for calling `async`/`await` functions from the live
    /// implementation of dependencies, such as `URLSession.data`, `MKLocalSearch.start` and more.
    ///
    /// - Parameters:
    ///   - priority: Priority of the underlying task. If `nil`, the priority will come from
    ///     `Task.currentPriority`.
    ///   - operation: The operation to execute.
    /// - Returns: An effect wrapping the given asynchronous work.
    public static func task(
      priority: TaskPriority? = nil,
      operation: @escaping @Sendable () async throws -> Output
    ) -> Self where Failure == Error {
      Deferred<Publishers.HandleEvents<PassthroughSubject<Output, Failure>>> {
        let subject = PassthroughSubject<Output, Failure>()
        let task = Task(priority: priority) { @MainActor in
          do {
            try Task.checkCancellation()
            let output = try await operation()
            try Task.checkCancellation()
            subject.send(output)
            subject.send(completion: .finished)
          } catch is CancellationError {
            subject.send(completion: .finished)
          } catch {
            subject.send(completion: .failure(error))
          }
        }
        return subject.handleEvents(receiveCancel: task.cancel)
      }
      .eraseToEffect()
    }

    /// Creates an effect that executes some work in the real world that doesn't need to feed data
    /// back into the store. If an error is thrown, the effect will complete and the error will be ignored.
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
#endif
