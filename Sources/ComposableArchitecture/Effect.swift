import Combine
import Foundation
import SwiftUI

public struct Effect<Action> {
  @usableFromInline
  enum Operation {
    case none
    case sync(@Sendable (Send<Action>.Continuation) -> Void)
    case run(TaskPriority? = nil, @Sendable (_ send: Send<Action>) async -> Void)
    
    @usableFromInline
    static func publisher(_ publisher: some Publisher<Action, Never>) -> Self {
      withEscapedDependencies { dependencies in
        .sync { continuation in
          let cancellable = publisher
            .handleEvents(receiveCancel: {
              continuation.finish()  // TODO: should this be cancel?
            })
            .sink { completion in
              continuation.finish()
            } receiveValue: { action in
              dependencies.yield {
                continuation(action)
              }
            }
          continuation.onTermination { _ in
            cancellable.cancel()
          }
        }
      }
    }
  }

  @usableFromInline
  let operation: Operation // [Operation]

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

  @usableFromInline
  static func sync(
    operation: @escaping @Sendable (_ send: Send<Action>.Continuation) -> Void,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) -> Self {
    withEscapedDependencies { dependencies in
      Self(
        operation: .sync { continuation in
          dependencies.yield {
            operation(continuation)
          }
        }
      )
    }
  }

  /// Wraps an asynchronous unit of work that can emit actions any number of times in an effect.
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
  /// The closure provided to ``run(priority:operation:catch:fileID:line:)`` is allowed to
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
    operation: @escaping @Sendable (_ send: Send<Action>) async throws -> Void,
    catch handler: (@Sendable (_ error: Error, _ send: Send<Action>) async -> Void)? = nil,
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
    Self(operation: .sync { $0(action); $0.finish() })
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
/// ``Effect/run(priority:operation:catch:fileID:line:)``.
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
/// See ``Effect/run(priority:operation:catch:fileID:line:)`` for more information on how to
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

  public struct Continuation: Sendable {
    let send: @Sendable (Action) -> Void
    @usableFromInline
    init(send: @escaping @Sendable (Action) -> Void) {
      self.send = send
    }
    public var onTermination: @Sendable (Termination) -> Void {
      get {
        self.storage.onTermination
      }
      nonmutating set {
        let t = self.storage.onTermination
        self.storage.onTermination = {
          newValue($0)
          t($0)
        }
      }
    }
    public func onTermination(_ newTermination: @escaping @Sendable (Termination) -> Void) {
      let current = self.storage.onTermination
      self.onTermination = { @Sendable action in
        current(action)
        newTermination(action)
      }
    }
    public var isFinished: Bool { self.storage.isFinished }
    let storage = Storage()
    public func finish() {
      guard !self.storage.isFinished
      else { return }
      self.storage.isFinished = true
      self.onTermination(.finished)
    }
    public func callAsFunction(_ action: Action) {
      self.send(action)
    }
    public func callAsFunction(_ action: Action, animation: Animation?) {
      callAsFunction(action, transaction: Transaction(animation: animation))
    }
    public func callAsFunction(_ action: Action, transaction: Transaction) {
      withTransaction(transaction) {
        self(action)
      }
    }
    final class Storage: @unchecked Sendable {
      var onTermination: @Sendable (Termination) -> Void
      var isFinished = false
      init(onTermination: @escaping @Sendable (Termination) -> Void = { _ in }) {
        self.onTermination = onTermination
      }
    }
    public enum Termination: Sendable {
      case finished
      case cancelled
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
    case let (.sync(lhsOperation), .sync(rhsOperation)):
      return .sync { continuation in
        let lhsContinuation = Send.Continuation { continuation($0) }
        let rhsContinuation = Send.Continuation { continuation($0) }
        lhsContinuation.onTermination { _ in
          guard rhsContinuation.isFinished
          else { return }
          continuation.finish()
        }
        rhsContinuation.onTermination { _ in
          guard lhsContinuation.isFinished
          else { return }
          continuation.finish()
        }
        lhsOperation(lhsContinuation)
        rhsOperation(rhsContinuation)
      }
    case (.run, .sync), (.sync, .run):
      return .publisher {
        Publishers.Merge(
          _EffectPublisher(self),
          _EffectPublisher(other)
        )
        .eraseToAnyPublisher()
      }
    case let (.run(lhsPriority, lhsOperation), .run(rhsPriority, rhsOperation)):
      return .run { send in
        await withTaskGroup(of: Void.self) { group in
          group.addTask(priority: lhsPriority) {
            await lhsOperation(send)
          }
          group.addTask(priority: rhsPriority) {
            await rhsOperation(send)
          }
        }
      }
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
    case let (.sync(lhsOperation), .sync(rhsOperation)):
      return .sync { continuation in
        let lhsContinuation = Send.Continuation { continuation($0) }
        lhsContinuation.onTermination {
          guard $0 != .cancelled else { return }
          rhsOperation(continuation)
        }
        lhsOperation(lhsContinuation)
      }
    case (.run, .sync), (.sync, .run):
      return .publisher {
        Publishers.Concatenate(
          prefix: _EffectPublisher(self),
          suffix: _EffectPublisher(other)
        )
        .eraseToAnyPublisher()

      }

    case let (.run(lhsPriority, lhsOperation), .run(rhsPriority, rhsOperation)):
      return .run { send in
        await withTaskGroup(of: Void.self) { group in
          group.addTask(priority: lhsPriority) {
            await lhsOperation(send)
          }
          await group.waitForAll()
          group.addTask(priority: rhsPriority) {
            await rhsOperation(send)
          }
        }
      }
    }
  }

  /// Transforms all elements from the upstream effect with a provided closure.
  ///
  /// - Parameter transform: A closure that transforms the upstream effect's action to a new action.
  /// - Returns: A publisher that uses the provided closure to map elements from the upstream effect
  ///   to new elements that it then publishes.
  @inlinable
  public func map<T>(_ transform: @escaping (Action) -> T) -> Effect<T> {
    switch self.operation {
    case .none:
      return .none
    case let .sync(operation):
      return .sync { continuation in
        let transformedContinuation = Send.Continuation { action in
          continuation(transform(action))
        }
        transformedContinuation.onTermination {
          switch $0 {
          case .cancelled:
            continuation.onTermination(.cancelled)
          case .finished:
            continuation.onTermination(.finished)
          }
        }
        operation(transformedContinuation)
      }

    case let .run(priority, operation):
      return .run(priority: priority) { send in
        await operation(
          Send { action in
            send(transform(action))
          }
        )
      }
    }
  }
}
