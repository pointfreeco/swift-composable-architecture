import Combine
import Foundation
import SwiftUI
import XCTestDynamicOverlay

public struct Effect<Action> {

  public struct _Operation {
    // TODO: This should be non-optional?
    @usableFromInline
    let sync: ((Send<Action>.Continuation) -> Void)?
    @usableFromInline
    let async: (priority: TaskPriority?, operation: ((Send<Action>) async -> Void))?

    // sync: ((Send<Action>.Continuation) -> ((Send<Action>) async -> Void)

    /*
     TODO: or:
     // Sync work done first, wait for continuation to finish, then start async operation, pass trask to trailing Void async work
     let sync: ((Send<Action>.Continuation) -> ((Task) -> Void))?
     */

    public init(
      sync: ((Send<Action>.Continuation) -> Void)? = nil,
      async: (priority: TaskPriority?, operation: ((Send<Action>) async -> Void))? = nil
    ) {
      self.sync = sync
      self.async = async
    }

    @usableFromInline
    func map<T>(_ transform: @escaping (Action) -> T) -> Effect<T>._Operation {
      .init(
        // TODO: pass along termination
        // TODO: pass along dependencies
        sync: self.sync.map { (sync: @escaping (Send<Action>.Continuation) -> Void) -> ((Send<T>.Continuation) -> Void) in
          withEscapedDependencies { escaped in
            { (sendT: Send<T>.Continuation) -> Void in
              sync(
                Send<Action>.Continuation(
                  send: { action in
                    escaped.yield {
                      sendT(transform(action))
                    }
                  },
                  storage: sendT.storage
                )
              )
            }
          }
        },
        async: self.async.map { priority, operation in
          withEscapedDependencies { escaped in
            (priority, { send in
              await escaped.yield {
                await operation(
                  Send { action in
                    send(transform(action))
                  }
                )
              }
            })
          }
        }
      )
    }
  }


//  @usableFromInline
//  enum Operation {
//    case none
//    case publisher(AnyPublisher<Action, Never>)
//    case run(TaskPriority? = nil, @Sendable (_ send: Send<Action>) async -> Void)
//  }

  @usableFromInline
  let operations: [_Operation]

  public init(operations: [_Operation]) {
    self.operations = operations
  }

  public func onComplete(_ completion: @Sendable @escaping () -> Void) -> Self {
    let completedCount = LockIsolated(0)
    return .init(operations: self.operations.map { operation in
        .init(
          sync: operation.sync.map { sync in
            { continuation in
              if operation.async == nil {
                continuation.onTermination { _ in
                  completedCount.withValue {
                    $0 += 1
                    if $0 == self.operations.count {
                      completion()
                    }
                  }
                }
              }
              sync(continuation)
            }
          },
          async: operation.async.map { priority, async in
            (priority, { send in
              await async(send)
              completedCount.withValue {
                $0 += 1
                if $0 == self.operations.count {
                  completion()
                }
              }
            })
          }
        )
    })
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
    Self(operations: [])
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
    line: UInt = #line
  ) -> Self {
    withEscapedDependencies { escaped in
      Self(
        operations: [_Operation(async: (priority, { send in
          await escaped.yield {
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
                    An "Effect.run" returned from "\(fileID):\(line)" threw an unhandled error. …

                    \(errorDump)

                    All non-cancellation errors must be explicitly handled via the "catch" parameter \
                    on "Effect.run", or via a "do" block.
                    """
                )
#endif
                return
              }
              await handler(error, send)
            }
          }
        }))]
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
    .init(
      operations: [.init(
        sync: { send in
          send(action)
          send.finish()
        }
      )]
    )
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



  public struct Continuation: Sendable {
    let send: @Sendable (Action) -> Void
    public init(
      send: @Sendable @escaping (Action) -> Void,
      storage: Storage = Storage()
    ) {
      self.send = send
      self.storage = storage
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
    public func onTermination(_ newTermination: @Sendable @escaping (Termination) -> Void) {
      let current = self.storage.onTermination
      self.onTermination = { @Sendable action in
        current(action)
        newTermination(action)
      }
    }
    public var isFinished: Bool { self.storage.isFinished }
    public let storage: Storage
    public func finish() {
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
  }
  

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


// TODO: fix sendable
public final class Storage: @unchecked Sendable {
  var onTermination: @Sendable (Termination) -> Void
  var isFinished = false
  public init(onTermination: @Sendable @escaping (Termination) -> Void = { _ in }) {
    self.onTermination = onTermination
  }
}
public enum Termination {
  case finished
  case cancelled
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
  public static func merge<S: Sequence>(_ effects: S) -> Self where S.Element == Self {
    effects.reduce(.none) { $0.merge(with: $1) }
  }

  /// Merges this effect and another into a single effect that runs both at the same time.
  ///
  /// - Parameter other: Another effect.
  /// - Returns: An effect that runs this effect and the other at the same time.
  @inlinable
  public func merge(with other: Self) -> Self {
    .init(operations: self.operations + other.operations)
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
    let totalAsyncCount = (self.operations + other.operations).filter { $0.async != nil }.count
    let totalSelfAsyncCount = self.operations.filter({ $0.async != nil }).count
    let totalOtherSyncCount = other.operations.filter { $0.sync != nil }.count

    func runSyncs(
      operations: [Effect<Action>._Operation],
      continuation: @escaping (Action) -> Void,
      onCompletion: @escaping () -> Void
    ) {
      let syncCount = operations.filter { $0.sync != nil }.count
      let syncCompleteCount = LockIsolated(0)
      for operation in operations {
        guard let sync = operation.sync else { continue }

        let childContinuation = Send<Action>.Continuation { continuation($0) }
        childContinuation.onTermination { _ in
          syncCompleteCount.withValue {
            $0 += 1
            if $0 == syncCount {
              onCompletion()
            }
          }
        }
        sync(childContinuation)
      }
      if syncCount == 0 {
        onCompletion()
      }
    }

    return .init(
      operations: [
        .init(
          sync: { continuation in
            runSyncs(operations: self.operations, continuation: { continuation($0) }) {
              if totalSelfAsyncCount > 0 {
                continuation.finish()
              } else {
                runSyncs(operations: other.operations, continuation: { continuation($0) }) {
                  continuation.finish()
                }
              }
            }
          },
          async: totalAsyncCount == 0 ? nil : (nil, { send in
            if totalSelfAsyncCount > 0 {
              await withTaskGroup(of: Void.self) { group in
                for operation in self.operations {
                  if let async = operation.async {
                    group.addTask {
                      await async.operation(send)
                    }
                  }
                }
              }

              let channel = AsyncStream<Action>.makeStream()
              runSyncs(operations: other.operations, continuation: {
                channel.continuation.yield($0)
              }) {
                channel.continuation.finish()
              }

              if totalOtherSyncCount != 0 {
                for await action in channel.stream {
                  await send(action)
                }
              }
            }

            await withTaskGroup(of: Void.self) { group in
              for operation in other.operations {
                if let async = operation.async {
                  group.addTask {
                    await async.operation(send)
                  }
                }
              }
            }
          })
        )
      ]
    )



//    .init(
//      operations: [.init(
//        sync: { continuation in
//          if let selfSync = self.operations.sync {
//            print(#line)
//            let c = Send<Action>.Continuation { action in continuation(action) }
//            c.onTermination { _ in
//              if let otherSync = other.operation.sync {
//                print(#line)
//                let c1 = Send<Action>.Continuation { action in continuation(action) }
//                c1.onTermination { _ in
//                  continuation.finish()
//                }
//                otherSync(c1)
//              } else {
//                print(#line)
//                continuation.finish()
//              }
//            }
//            selfSync(c)
//          } else if let otherSync = other.operation.sync {
//            print(#line)
//            let c1 = Send<Action>.Continuation { action in continuation(action) }
//            c1.onTermination { _ in
//              continuation.finish()
//            }
//            otherSync(c1)
//          } else {
//            print(#line)
//            continuation.finish()
//          }
//
////          if let selfSync = self.operation.sync {
////            print(#line)
////            continuation.onTermination { _ in
////              if let otherSync = other.operation.sync {
////                print(#line)
////                otherSync(continuation)
////              } else {
////                print(#line)
////                continuation.finish()
////              }
////            }
////            selfSync(continuation)
////          } else if let otherSync = other.operation.sync {
////            print(#line)
////            otherSync(continuation)
////          } else {
////            print(#line)
////            continuation.finish()
////          }
//        }//,
////        async: (nil, { send in
////          if let lhsPriority = self.operation.async?.priority {
////            await Task(priority: lhsPriority) { await self.operation.async?.operation(send) }.cancellableValue
////          } else {
////            await self.operation.async?.operation(send)
////          }
////          if let rhsPriority = other.operation.async?.priority {
////            await Task(priority: rhsPriority) { await other.operation.async?.operation(send) }.cancellableValue
////          } else {
////            await other.operation.async?.operation(send)
////          }
////        })
//      )]
//    )
  }

  /// Transforms all elements from the upstream effect with a provided closure.
  ///
  /// - Parameter transform: A closure that transforms the upstream effect's action to a new action.
  /// - Returns: A publisher that uses the provided closure to map elements from the upstream effect
  ///   to new elements that it then publishes.
  @inlinable
  public func map<T>(_ transform: @escaping (Action) -> T) -> Effect<T> {
    .init(operations: self.operations.map { $0.map(transform) })
  }
}
