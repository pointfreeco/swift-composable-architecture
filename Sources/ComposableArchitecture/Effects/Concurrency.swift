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
        let task = Task(priority: priority) {
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
    /// back into the store.
    ///
    /// - Parameters:
    ///   - priority: Priority of the underlying task. If `nil`, the priority will come from
    ///     `Task.currentPriority`.
    ///   - work: A closure encapsulating some work to execute in the real world.
    /// - Returns: An effect.
    public static func fireAndForget(
      priority: TaskPriority? = nil,
      _ work: @escaping @Sendable () async -> Void
    ) -> Effect {
      Effect<Void, Never>.task(priority: priority) { await work() }
        .fireAndForget()
    }
  }

extension Effect where Failure == Never {
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
    Effect<Output, Error>.task(priority: priority, operation: operation)
      .catch { _ in Empty() }
      .eraseToEffect()
  }

  public static func task(
    priority: TaskPriority? = nil,
    operation: @escaping @Sendable () async throws -> Output,
    `catch`: @escaping (Error) -> Output? = { _ in nil }
  ) -> Self {
    Effect<Output, Error>.task(priority: priority, operation: operation)
      .catch { (error: Error) -> AnyPublisher<Output, Never> in
        if let output = `catch`(error) {
          return Just(output).eraseToAnyPublisher()
        } else {
          return Empty().eraseToAnyPublisher()
        }
      }
      .eraseToEffect()
  }
}
#endif

import SwiftUI
public struct Send<Action> {
  let send: (Action) -> Void
  public func callAsFunction(_ action: Action) {
    self.send(action)
  }
  public func callAsFunction(_ action: Action, animation: Animation? = nil) {
    withAnimation(animation) {
      self.send(action)
    }
  }
  func pullback<NewAction>(_ f: @escaping (NewAction) -> Action) -> Send<NewAction> {
    .init(send: { newAction in self.send(f(newAction)) })
  }
}

extension Effect where Failure == Error {
  public static func run(
    priority: TaskPriority? = nil,
    _ operation: @escaping (_ send: Send<Output>) async throws -> Void
  ) -> Self {
    .run { subscriber in
      let task = Task(priority: priority) {
        do {
          try await operation(Send(send: subscriber.send(_:)))
        } catch {
          subscriber.send(completion: .failure(error))
        }
        subscriber.send(completion: .finished)
      }
      return AnyCancellable {
        task.cancel()
      }
    }
  }
}

extension Effect where Failure == Never {
  public static func run(
    priority: TaskPriority? = nil,
    _ operation: @escaping (_ send: Send<Output>) async -> Void
  ) -> Self {
    .run { subscriber in
      let task = Task(priority: priority) {
        await operation(Send(send: subscriber.send(_:)))
        subscriber.send(completion: .finished)
      }
      return AnyCancellable {
        task.cancel()
      }
    }
  }

  public static func run(
    priority: TaskPriority? = nil,
    _ operation: @escaping (_ send: Send<Output>) async throws -> Void,
    `catch`: @escaping (Error) -> Output? = { _ in nil }
  ) -> Self {
    .run { subscriber in
      let task = Task(priority: priority) {
        do {
          let send = Send(send: subscriber.send(_:))
          try await operation(send)
        } catch {
          if let output = `catch`(error) {
            subscriber.send(output)
          }
        }
        subscriber.send(completion: .finished)
      }
      return AnyCancellable {
        task.cancel()
      }
    }
  }
}
