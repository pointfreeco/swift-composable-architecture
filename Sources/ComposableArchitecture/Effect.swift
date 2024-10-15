@preconcurrency import Combine
import Foundation
import SwiftUI

public struct Effect<Action>: Sendable {
  @usableFromInline
  enum Operation: Sendable {
    case none
    case publisher(AnyPublisher<Action, Never>)
    case run(TaskPriority? = nil, @Sendable (_ send: Send<Action>) async -> Void)
  }

  @usableFromInline
  let operation: Operation

  @usableFromInline
  init(operation: Operation) {
    self.operation = operation
  }
}

/// A convenience type alias for referring to an effect of a given reducer's domain.
///
/// Instead of specifying the action:
///
/// ```swift
/// let effect: Effect<Feature.Action>
/// ```
///
/// You can specify the reducer:
///
/// ```swift
/// let effect: EffectOf<Feature>
/// ```
public typealias EffectOf<R: Reducer> = Effect<R.Action>

// MARK: - Creating Effects

extension Effect {
  /// An effect that does nothing and completes immediately. Useful for situations where you must
  /// return an effect, but you don't need to do anything.
  @inlinable
  public static var none: Self {
    Self(operation: .none)
  }

  /// Wraps an asynchronous unit of work that can emit actions any number of times in an effect.
  ///
  /// For example, if you had an async sequence in a dependency client:
  ///
  /// ```swift
  /// struct EventsClient {
  ///   var events: () -> any AsyncSequence<Event, Never>
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
  /// The closure provided to ``run(priority:operation:catch:fileID:filePath:line:column:)`` is
  /// allowed to throw, but any non-cancellation errors thrown will cause a runtime warning when run
  /// in the simulator or on a device, and will cause a test failure in tests. To catch
  /// non-cancellation errors use the `catch` trailing closure.
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
    operation: @escaping @Sendable (_ send: Send<Action>) async throws -> Void,
    catch handler: (@Sendable (_ error: any Error, _ send: Send<Action>) async -> Void)? = nil,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) -> Self {
    withEscapedDependencies { escaped in
      Self(
        operation: .run(priority) { send in
          await escaped.yield {
            do {
              try await operation(send)
            } catch is CancellationError {
              return
            } catch {
              guard let handler else {
                reportIssue(
                  """
                  An "Effect.run" returned from "\(fileID):\(line)" threw an unhandled error. …

                  \(String(customDumping: error).indent(by: 4))

                  All non-cancellation errors must be explicitly handled via the "catch" parameter \
                  on "Effect.run", or via a "do" block.
                  """,
                  fileID: fileID,
                  filePath: filePath,
                  line: line,
                  column: column
                )
                return
              }
              await handler(error, send)
            }
          }
        }
      )
    }
  }

  /// Initializes an effect that immediately emits the action passed in.
  ///
  /// > Note: We do not recommend using `Effect.send` to share logic. Instead, limit usage to
  /// > child-parent communication, where a child may want to emit a "delegate" action for a parent
  /// > to listen to.
  /// >
  /// > For more information, see <doc:Performance#Sharing-logic-with-actions>.
  ///
  /// - Parameter action: The action that is immediately emitted by the effect.
  public static func send(_ action: Action) -> Self {
    Self(operation: .publisher(Just(action).eraseToAnyPublisher()))
  }

  /// Initializes an effect that immediately emits the action passed in.
  ///
  /// > Note: We do not recommend using `Effect.send` to share logic. Instead, limit usage to
  /// > child-parent communication, where a child may want to emit a "delegate" action for a parent
  /// > to listen to.
  /// >
  /// > For more information, see <doc:Performance#Sharing-logic-with-actions>.
  ///
  /// - Parameters:
  ///   - action: The action that is immediately emitted by the effect.
  ///   - animation: An animation.
  public static func send(_ action: Action, animation: Animation? = nil) -> Self {
    .send(action).animation(animation)
  }
}

/// A type that can send actions back into the system when used from
/// ``Effect/run(priority:operation:catch:fileID:filePath:line:column:)``.
///
/// This type implements [`callAsFunction`][callAsFunction] so that you invoke it as a function
/// rather than calling methods on it:
///
/// ```swift
/// return .run { send in
///   await send(.started)
///   for await event in self.events {
///     send(.event(event))
///   }
///   await send(.finished)
/// }
/// ```
///
/// You can also send actions with animation and transaction:
///
/// ```swift
/// await send(.started, animation: .spring())
/// await send(.finished, transaction: .init(animation: .default))
/// ```
///
/// See ``Effect/run(priority:operation:catch:fileID:filePath:line:column:)`` for more information on how to
/// use this value to construct effects that can emit any number of times in an asynchronous
/// context.
///
/// [callAsFunction]: https://docs.swift.org/swift-book/ReferenceManual/Declarations.html#ID622
@MainActor
public struct Send<Action>: Sendable {
  let send: @MainActor @Sendable (Action) -> Void

  public init(send: @escaping @MainActor @Sendable (Action) -> Void) {
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
    callAsFunction(action, transaction: Transaction(animation: animation))
  }

  /// Sends an action back into the system from an effect with transaction.
  ///
  /// - Parameters:
  ///   - action: An action.
  ///   - transaction: A transaction.
  public func callAsFunction(_ action: Action, transaction: Transaction) {
    guard !Task.isCancelled else { return }
    withTransaction(transaction) {
      self(action)
    }
  }
}

// MARK: - Composing Effects

extension Effect {
  /// Merges a variadic list of effects together into a single effect, which runs the effects at the
  /// same time.
  ///
  /// - Parameter effects: A variadic list of effects.
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
  public static func merge(_ effects: some Sequence<Self>) -> Self {
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
      return Self(
        operation: .publisher(
          Publishers.Merge(
            _EffectPublisher(self),
            _EffectPublisher(other)
          )
          .eraseToAnyPublisher()
        )
      )
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
  public static func concatenate(_ effects: some Collection<Self>) -> Self {
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
          Publishers.Concatenate(
            prefix: _EffectPublisher(self),
            suffix: _EffectPublisher(other)
          )
          .eraseToAnyPublisher()
        )
      )
    case let (.run(lhsPriority, lhsOperation), .run(rhsPriority, rhsOperation)):
      return Self(
        operation: .run { send in
          if let lhsPriority {
            await Task(priority: lhsPriority) { await lhsOperation(send) }.cancellableValue
          } else {
            await lhsOperation(send)
          }
          if let rhsPriority {
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
  public func map<T>(_ transform: @escaping @Sendable (Action) -> T) -> Effect<T> {
    switch self.operation {
    case .none:
      return .none
    case let .publisher(publisher):
      return .init(
        operation: .publisher(
          publisher
            .map(
              withEscapedDependencies { escaped in
                { action in
                  escaped.yield {
                    transform(action)
                  }
                }
              }
            )
            .eraseToAnyPublisher()
        )
      )
    case let .run(priority, operation):
      return withEscapedDependencies { escaped in
        .init(
          operation: .run(priority) { send in
            await escaped.yield {
              await operation(
                Send { action in
                  send(transform(action))
                }
              )
            }
          }
        )
      }
    }
  }
}
