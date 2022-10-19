import Combine
import Foundation
import SwiftUI
import XCTestDynamicOverlay

/// A type that encapsulates a unit of work that can be run in the outside world, and can feed
/// actions back to the ``Store``.
///
/// Effects are the perfect place to do side effects, such as network requests, saving/loading
/// from disk, creating timers, interacting with dependencies, and more. They are returned from
/// reducers so that the ``Store`` can perform the effects after the reducer is done running.
///
/// There are 2 distinct ways to create an `Effect`: one using Swift's native concurrency tools, and
/// the other using Apple's Combine framework:
///
/// * If using Swift's native structured concurrency tools then there are 3 main ways to create an
/// effect, depending on if you want to emit one single action back into the system, or any number
/// of actions, or just execute some work without emitting any actions:
///   * ``EffectPublisher/task(priority:operation:catch:file:fileID:line:)``
///   * ``EffectPublisher/run(priority:operation:catch:file:fileID:line:)``
///   * ``EffectPublisher/fireAndForget(priority:_:)``
/// * If using Combine in your application, in particular for the dependencies of your feature
/// then you can create effects by making use of any of Combine's operators, and then erasing the
/// publisher type to ``EffectPublisher`` with either `eraseToEffect` or `catchToEffect`. Note that
/// the Combine interface to ``EffectPublisher`` is considered soft deprecated, and you should
/// eventually port to Swift's native concurrency tools.
///
/// > Important: ``Store`` is not thread safe, and so all effects must receive values on the same
/// thread. This is typically the main thread,  **and** if the store is being used to drive UI then
/// it must receive values on the main thread.
/// >
/// > This is only an issue if using the Combine interface of ``EffectPublisher`` as mentioned
/// above. If  you are using Swift's concurrency tools and the `.task`, `.run` and `.fireAndForget`
/// functions on ``EffectTask``, then threading is automatically handled for you.
public struct EffectPublisher<Action, Failure: Error> {
  @usableFromInline
  enum Operation {
    case none
    case publisher(AnyPublisher<Action, Failure>)
    case run(TaskPriority? = nil, @Sendable (Send<Action>) async -> Void)
  }

  @usableFromInline
  let operation: Operation

  @usableFromInline
  init(operation: Operation) {
    self.operation = operation
  }
}

// MARK: - Creating Effects

extension EffectPublisher {
  /// An effect that does nothing and completes immediately. Useful for situations where you must
  /// return an effect, but you don't need to do anything.
  @inlinable
  public static var none: Self {
    Self(operation: .none)
  }
}

/// A convenience type alias for referring to an effect that can never fail, like the kind of
/// ``EffectPublisher`` returned by a reducer after processing an action.
///
/// Instead of specifying `Never` as `Failure`:
///
/// ```swift
/// func reduce(into state: inout State, action: Action) -> EffectPublisher<Action, Never> { … }
/// ```
///
/// You can specify a single generic:
///
/// ```swift
/// func reduce(into state: inout State, action: Action) -> EffectTask<Action>  { … }
/// ```
public typealias EffectTask<Action> = Effect<Action, Never>

extension EffectPublisher where Failure == Never {
  /// Wraps an asynchronous unit of work in an effect.
  ///
  /// This function is useful for executing work in an asynchronous context and capturing the result
  /// in an ``EffectTask`` so that the reducer, a non-asynchronous context, can process it.
  ///
  /// For example, if your dependency exposes an `async` function, you can use
  /// ``task(priority:operation:catch:file:fileID:line:)`` to provide an asynchronous context for
  /// invoking that endpoint:
  ///
  /// ```swift
  /// struct Feature: ReducerProtocol {
  ///   struct State { … }
  ///   enum FeatureAction {
  ///     case factButtonTapped
  ///     case faceResponse(TaskResult<String>)
  ///   }
  ///   @Dependency(\.numberFact) var numberFact
  ///
  ///   func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
  ///     switch action {
  ///       case .factButtonTapped:
  ///         return .task { [number = state.number] in
  ///           await .factResponse(TaskResult { try await self.numberFact.fetch(number) })
  ///         }
  ///
  ///       case .factResponse(.success(fact)):
  ///         // do something with fact
  ///
  ///       case .factResponse(.failure):
  ///         // handle error
  ///
  ///       ...
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// The above code sample makes use of ``TaskResult`` in order to automatically bundle the success
  /// or failure of the `numberFact` endpoint into a single type that can be sent in an action.
  ///
  /// The closure provided to ``task(priority:operation:catch:file:fileID:line:)`` is allowed to
  /// throw, but any non-cancellation errors thrown will cause a runtime warning when run in the
  /// simulator or on a device, and will cause a test failure in tests. To catch non-cancellation
  /// errors use the `catch` trailing closure.
  ///
  /// - Parameters:
  ///   - priority: Priority of the underlying task. If `nil`, the priority will come from
  ///     `Task.currentPriority`.
  ///   - operation: The operation to execute.
  ///   - catch: An error handler, invoked if the operation throws an error other than
  ///     `CancellationError`.
  /// - Returns: An effect wrapping the given asynchronous work.
  public static func task(
    priority: TaskPriority? = nil,
    operation: @escaping @Sendable () async throws -> Action,
    catch handler: (@Sendable (Error) async -> Action)? = nil,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    let dependencies = DependencyValues._current
    return Self(
      operation: .run(priority) { send in
        await DependencyValues.$_current.withValue(dependencies) {
          do {
            try await send(operation())
          } catch is CancellationError {
            return
          } catch {
            guard let handler = handler else {
              #if DEBUG
                var errorDump = ""
                customDump(error, to: &errorDump, indent: 4)
                runtimeWarn(
                  """
                  An "EffectTask.task" returned from "\(fileID):\(line)" threw an unhandled error. …

                  \(errorDump)

                  All non-cancellation errors must be explicitly handled via the "catch" parameter \
                  on "EffectTask.task", or via a "do" block.
                  """,
                  file: file,
                  line: line
                )
              #endif
              return
            }
            await send(handler(error))
          }
        }
      }
    )
  }

  /// Wraps an asynchronous unit of work that can emit any number of times in an effect.
  ///
  /// This effect is similar to ``task(priority:operation:catch:file:fileID:line:)`` except it is
  /// capable of emitting 0 or more times, not just once.
  ///
  /// For example, if you had an async stream in a dependency client:
  ///
  /// ```swift
  /// struct EventsClient {
  ///   var events: () -> AsyncStream<Event>
  /// }
  /// ```
  ///
  /// Then you could attach to it in a `run` effect by using `for await` and sending each action of
  /// the stream back into the system:
  ///
  /// ```swift
  /// case .startButtonTapped:
  ///   return .run { send in
  ///     for await event in self.events() {
  ///       send(.event(event))
  ///     }
  ///   }
  /// ```
  ///
  /// See ``Send`` for more information on how to use the `send` argument passed to `run`'s closure.
  ///
  /// The closure provided to ``run(priority:operation:catch:file:fileID:line:)`` is allowed to
  /// throw, but any non-cancellation errors thrown will cause a runtime warning when run in the
  /// simulator or on a device, and will cause a test failure in tests. To catch non-cancellation
  /// errors use the `catch` trailing closure.
  ///
  /// - Parameters:
  ///   - priority: Priority of the underlying task. If `nil`, the priority will come from
  ///     `Task.currentPriority`.
  ///   - operation: The operation to execute.
  ///   - catch: An error handler, invoked if the operation throws an error other than
  ///     `CancellationError`.
  /// - Returns: An effect wrapping the given asynchronous work.
  public static func run(
    priority: TaskPriority? = nil,
    operation: @escaping @Sendable (Send<Action>) async throws -> Void,
    catch handler: (@Sendable (Error, Send<Action>) async -> Void)? = nil,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    let dependencies = DependencyValues._current
    return Self(
      operation: .run(priority) { send in
        await DependencyValues.$_current.withValue(dependencies) {
          do {
            try await operation(send)
          } catch is CancellationError {
            return
          } catch {
            guard let handler = handler else {
              #if DEBUG
                var errorDump = ""
                customDump(error, to: &errorDump, indent: 4)
                runtimeWarn(
                  """
                  An "EffectTask.run" returned from "\(fileID):\(line)" threw an unhandled error. …

                  \(errorDump)

                  All non-cancellation errors must be explicitly handled via the "catch" parameter \
                  on "EffectTask.run", or via a "do" block.
                  """,
                  file: file,
                  line: line
                )
              #endif
              return
            }
            await handler(error, send)
          }
        }
      }
    )
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
  ///     try self.analytics.track("Button Tapped")
  ///   }
  /// ```
  ///
  /// The closure provided to ``fireAndForget(priority:_:)`` is allowed to throw, and any error
  /// thrown will be ignored.
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
    Self.run(priority: priority) { _ in try? await work() }
  }
}

/// A type that can send actions back into the system when used from
/// ``EffectPublisher/run(priority:operation:catch:file:fileID:line:)``.
///
/// This type implements [`callAsFunction`][callAsFunction] so that you invoke it as a function
/// rather than calling methods on it:
///
/// ```swift
/// return .run { send in
///   send(.started)
///   defer { send(.finished) }
///   for await event in self.events {
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
/// See ``EffectPublisher/run(priority:operation:catch:file:fileID:line:)`` for more information on how to
/// use this value to construct effects that can emit any number of times in an asynchronous
/// context.
///
/// [callAsFunction]: https://docs.swift.org/swift-book/ReferenceManual/Declarations.html#ID622
@MainActor
public struct Send<Action> {
  public let send: @MainActor (Action) -> Void

  public init(send: @escaping @MainActor (Action) -> Void) {
    self.send = send
  }

  /// Sends an action back into the system from an effect.
  ///
  /// - Parameter action: An action.
  public func callAsFunction(_ action: Action) {
    guard !Task.isCancelled else { return }
    self.send(action)
  }

  /// Sends an action back into the system from an effect with animation.
  ///
  /// - Parameters:
  ///   - action: An action.
  ///   - animation: An animation.
  public func callAsFunction(_ action: Action, animation: Animation?) {
    guard !Task.isCancelled else { return }
    withAnimation(animation) {
      self(action)
    }
  }
}

// MARK: - Composing Effects

extension EffectPublisher {
  /// Merges a variadic list of effects together into a single effect, which runs the effects at the
  /// same time.
  ///
  /// - Parameter effects: A list of effects.
  /// - Returns: A new effect
  @inlinable
  public static func merge(_ effects: Self...) -> Self {
    Self.merge(effects)
  }

  /// Merges a sequence of effects together into a single effect, which runs the effects at the same
  /// time.
  ///
  /// - Parameter effects: A sequence of effects.
  /// - Returns: A new effect
  @inlinable
  public static func merge<S: Sequence>(_ effects: S) -> Self where S.Element == Self {
    effects.reduce(.none) { $0.merge(with: $1) }
  }

  /// Merges this effect and another into a single effect that runs both at the same time.
  ///
  /// - Parameter other: Another effect.
  /// - Returns: An effect that runs this effect and the other at the same time.
  @inlinable
  public func merge(with other: Self) -> Self {
    switch (self.operation, other.operation) {
    case (_, .none):
      return self
    case (.none, _):
      return other
    case (.publisher, .publisher), (.run, .publisher), (.publisher, .run):
      return Self(operation: .publisher(Publishers.Merge(self, other).eraseToAnyPublisher()))
    case let (.run(lhsPriority, lhsOperation), .run(rhsPriority, rhsOperation)):
      return Self(
        operation: .run { send in
          await withTaskGroup(of: Void.self) { group in
            group.addTask(priority: lhsPriority) {
              await lhsOperation(send)
            }
            group.addTask(priority: rhsPriority) {
              await rhsOperation(send)
            }
          }
        }
      )
    }
  }

  /// Concatenates a variadic list of effects together into a single effect, which runs the effects
  /// one after the other.
  ///
  /// - Parameter effects: A variadic list of effects.
  /// - Returns: A new effect
  @inlinable
  public static func concatenate(_ effects: Self...) -> Self {
    Self.concatenate(effects)
  }

  /// Concatenates a collection of effects together into a single effect, which runs the effects one
  /// after the other.
  ///
  /// - Parameter effects: A collection of effects.
  /// - Returns: A new effect
  @inlinable
  public static func concatenate<C: Collection>(_ effects: C) -> Self where C.Element == Self {
    effects.reduce(.none) { $0.concatenate(with: $1) }
  }

  /// Concatenates this effect and another into a single effect that first runs this effect, and
  /// after it completes or is cancelled, runs the other.
  ///
  /// - Parameter other: Another effect.
  /// - Returns: An effect that runs this effect, and after it completes or is cancelled, runs the
  ///   other.
  @inlinable
  @_disfavoredOverload
  public func concatenate(with other: Self) -> Self {
    switch (self.operation, other.operation) {
    case (_, .none):
      return self
    case (.none, _):
      return other
    case (.publisher, .publisher), (.run, .publisher), (.publisher, .run):
      return Self(
        operation: .publisher(
          Publishers.Concatenate(prefix: self, suffix: other).eraseToAnyPublisher()
        )
      )
    case let (.run(lhsPriority, lhsOperation), .run(rhsPriority, rhsOperation)):
      return Self(
        operation: .run { send in
          if let lhsPriority = lhsPriority {
            await Task(priority: lhsPriority) { await lhsOperation(send) }.cancellableValue
          } else {
            await lhsOperation(send)
          }
          if let rhsPriority = rhsPriority {
            await Task(priority: rhsPriority) { await rhsOperation(send) }.cancellableValue
          } else {
            await rhsOperation(send)
          }
        }
      )
    }
  }

  /// Transforms all elements from the upstream effect with a provided closure.
  ///
  /// - Parameter transform: A closure that transforms the upstream effect's action to a new action.
  /// - Returns: A publisher that uses the provided closure to map elements from the upstream effect
  ///   to new elements that it then publishes.
  @inlinable
  public func map<T>(_ transform: @escaping (Action) -> T) -> EffectPublisher<T, Failure> {
    switch self.operation {
    case .none:
      return .none
    case let .publisher(publisher):
      let dependencies = DependencyValues._current
      let transform = { action in
        DependencyValues.$_current.withValue(dependencies) {
          transform(action)
        }
      }
      return .init(operation: .publisher(publisher.map(transform).eraseToAnyPublisher()))
    case let .run(priority, operation):
      return .init(
        operation: .run(priority) { send in
          await operation(
            Send { action in
              send(transform(action))
            }
          )
        }
      )
    }
  }
}

// MARK: - Testing Effects

extension EffectPublisher {
  /// An effect that causes a test to fail if it runs.
  ///
  /// > Important: This Combine-based interface has been soft-deprecated in favor of Swift
  /// > concurrency. Prefer using async functions and `AsyncStream`s directly in your dependencies,
  /// > and using `unimplemented` from the [XCTest Dynamic Overlay](gh-xctest-dynamic-overlay)
  /// > library to stub in a function that fails when invoked:
  /// >
  /// > ```swift
  /// > struct NumberFactClient {
  /// >   var fetch: (Int) async throws -> String
  /// > }
  /// >
  /// > extension NumberFactClient: TestDependencyKey {
  /// >   static let testValue = Self(
  /// >     fetch: unimplemented(
  /// >       "\(Self.self).fetch",
  /// >       placeholder: "Not an interesting number."
  /// >     )
  /// >   }
  /// > }
  /// > ```
  ///
  /// This effect can provide an additional layer of certainty that a tested code path does not
  /// execute a particular effect.
  ///
  /// For example, let's say we have a very simple counter application, where a user can increment
  /// and decrement a number. The state and actions are simple enough:
  ///
  /// ```swift
  /// struct CounterState: Equatable {
  ///   var count = 0
  /// }
  ///
  /// enum CounterAction: Equatable {
  ///   case decrementButtonTapped
  ///   case incrementButtonTapped
  /// }
  /// ```
  ///
  /// Let's throw in a side effect. If the user attempts to decrement the counter below zero, the
  /// application should refuse and play an alert sound instead.
  ///
  /// We can model playing a sound in the environment with an effect:
  ///
  /// ```swift
  /// struct CounterEnvironment {
  ///   let playAlertSound: () -> EffectPublisher<Never, Never>
  /// }
  /// ```
  ///
  /// Now that we've defined the domain, we can describe the logic in a reducer:
  ///
  /// ```swift
  /// let counterReducer = AnyReducer<
  ///   CounterState, CounterAction, CounterEnvironment
  /// > { state, action, environment in
  ///   switch action {
  ///   case .decrementButtonTapped:
  ///     if state > 0 {
  ///       state.count -= 0
  ///       return .none
  ///     } else {
  ///       return environment.playAlertSound()
  ///         .fireAndForget()
  ///     }
  ///
  ///   case .incrementButtonTapped:
  ///     state.count += 1
  ///     return .none
  ///   }
  /// }
  /// ```
  ///
  /// Let's say we want to write a test for the increment path. We can see in the reducer that it
  /// should never play an alert, so we can configure the environment with an effect that will
  /// fail if it ever executes:
  ///
  /// ```swift
  /// @MainActor
  /// func testIncrement() async {
  ///   let store = TestStore(
  ///     initialState: CounterState(count: 0)
  ///     reducer: counterReducer,
  ///     environment: CounterEnvironment(
  ///       playSound: .unimplemented("playSound")
  ///     )
  ///   )
  ///
  ///   await store.send(.increment) {
  ///     $0.count = 1
  ///   }
  /// }
  /// ```
  ///
  /// By using an `.unimplemented` effect in our environment we have strengthened the assertion and
  /// made the test easier to understand at the same time. We can see, without consulting the
  /// reducer itself, that this particular action should not access this effect.
  ///
  /// [gh-xctest-dynamic-overlay]: http://github.com/pointfreeco/xctest-dynamic-overlay
  ///
  /// - Parameter prefix: A string that identifies this effect and will prefix all failure
  ///   messages.
  /// - Returns: An effect that causes a test to fail if it runs.
  @available(
    iOS, deprecated: 9999.0, message: "Call 'unimplemented' from your dependencies, instead."
  )
  @available(
    macOS, deprecated: 9999.0, message: "Call 'unimplemented' from your dependencies, instead."
  )
  @available(
    tvOS, deprecated: 9999.0, message: "Call 'unimplemented' from your dependencies, instead."
  )
  @available(
    watchOS, deprecated: 9999.0, message: "Call 'unimplemented' from your dependencies, instead."
  )
  public static func unimplemented(_ prefix: String) -> Self {
    .fireAndForget {
      XCTFail("\(prefix.isEmpty ? "" : "\(prefix) - ")An unimplemented effect ran.")
    }
  }
}

@available(
  iOS,
  deprecated: 9999.0,
  message:
    """
    'Effect' has been deprecated in favor of 'EffectTask' when `Failure == Never`, or
    `EffectPublisher<Output, Failure>` in general.
    
    You are encouraged to use `EffectTask<Action>` to model the ouput of your reducers, and to Swift
    concurrency to model failable streams of values.

    See the migration roadmap for more information: https://github.com/pointfreeco/swift-composable-architecture/discussions/1477
    """
)
@available(
  macOS,
  deprecated: 9999.0,
  message:
    """
    'Effect' has been deprecated in favor of 'EffectTask' when `Failure == Never`, or
    `EffectPublisher<Output, Failure>` in general.
    
    You are encouraged to use `EffectTask<Action>` to model the ouput of your reducers, and to Swift
    concurrency to model failable streams of values.

    See the migration roadmap for more information: https://github.com/pointfreeco/swift-composable-architecture/discussions/1477
    """
)
@available(
  tvOS,
  deprecated: 9999.0,
  message:
    """
    'Effect' has been deprecated in favor of 'EffectTask' when `Failure == Never`, or
    `EffectPublisher<Output, Failure>` in general.
    
    You are encouraged to use `EffectTask<Action>` to model the ouput of your reducers, and to Swift
    concurrency to model failable streams of values.

    See the migration roadmap for more information: https://github.com/pointfreeco/swift-composable-architecture/discussions/1477
    """
)
@available(
  watchOS,
  deprecated: 9999.0,
  message:
    """
    'Effect' has been deprecated in favor of 'EffectTask' when `Failure == Never`, or
    `EffectPublisher<Output, Failure>` in general.
    
    You are encouraged to use `EffectTask<Action>` to model the ouput of your reducers, and to Swift
    concurrency to model failable streams of values.

    See the migration roadmap for more information: https://github.com/pointfreeco/swift-composable-architecture/discussions/1477
    """
)
public typealias Effect = EffectPublisher
