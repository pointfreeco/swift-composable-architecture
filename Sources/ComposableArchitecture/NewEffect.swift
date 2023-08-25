import Combine
import SwiftUI

enum Operation<Action> {
  case async(priority: TaskPriority?, (Send<Action>) async -> Void)
  case escaping((EscapingSend<Action>) -> Void)
  var isEscaping: Bool {
    guard case .escaping = self else { return false }
    return true
  }
  var isAsync: Bool {
    guard case .async = self else { return false }
    return true
  }
}

struct NewEffect<Action> {
  let merged: [Operation<Action>]

  init(merged: [Operation<Action>]) {
    self.merged = merged
  }

  init(_ operation: Operation<Action>) {
    self.merged = [operation]
  }

  static func async(
    priority: TaskPriority? = nil, operation: @escaping (Send<Action>) async -> Void
  ) -> Self {
    .init(.async(priority: priority, operation))
  }

  static func escaping(_ work: @escaping (EscapingSend<Action>) -> Void) -> Self {
    .init(.escaping(work))
  }

  static func sync(_ work: @escaping (EscapingSend<Action>) -> Void) -> Self {
    .init(
      .escaping({
        work($0)
        $0.finish()
      }))
  }

  static func send(_ action: Action) -> Self {
    .sync { $0(action) }
  }

  static func publisher(_ createPublisher: @escaping () -> some Publisher<Action, Never>) -> Self {
    .init(
      .escaping { send in
        let cancellable = createPublisher()
          .sink(
            receiveCompletion: { _ in
              send.finish()
            },
            receiveValue: {
              send($0)
            }
          )
        send.onTermination { _ in
          _ = cancellable
          cancellable.cancel()
        }
      })
  }

  static var never: Self {
    .escaping { _ in }
  }
  static var none: Self {
    .init(merged: [])
  }

  func merge(with other: Self) -> Self {
    .init(merged: self.merged + other.merged)
  }

  func concat(with other: Self) -> Self {
    let asyncFinished = AsyncStream<Never>.makeStream()
    let escapingFinished = PassthroughSubject<Never, Never>()
    @Sendable
    func selfFinished() {
      escapingFinished.send(completion: .finished)
      asyncFinished.continuation.finish()
    }

    let selfHasEscapingOperations = self.merged.contains(where: \.isEscaping)
    let selfHasAsyncOperations = self.merged.contains(where: \.isAsync)
    let otherHasEscapingOperations = other.merged.contains(where: \.isEscaping)
    let otherHasAsyncOperations = other.merged.contains(where: \.isAsync)

    guard !self.merged.isEmpty && !other.merged.isEmpty
    else {
      return .init(merged: self.merged + other.merged)
    }

    var operations: [Operation<Action>] = []
    if otherHasEscapingOperations {
      operations.append(
        .escaping { send in
          let cancellable =
            escapingFinished
            .sink(
              receiveCompletion: { _ in
                other.runEscapingOperations(send: { send($0) }) {
                  send.finish()
                }
              },
              receiveValue: { _ in }
            )
          send.onTermination { _ in
            cancellable.cancel()
          }
        }
      )
    }
    if otherHasAsyncOperations {
      operations.append(
        .async(priority: nil) { send in
          for await _ in asyncFinished.stream {}
          await other.runAsyncOperations(send: { send($0) })
        }
      )
    }
    if selfHasEscapingOperations {
      operations.append(
        .escaping { send in
          self.runEscapingOperations(send: { send($0) }) {
            if !selfHasAsyncOperations {
              selfFinished()
            }
            send.finish()
          }
        }
      )
    }
    if selfHasAsyncOperations {
      operations.append(
        .async(priority: nil) { send in
          await self.runAsyncOperations(send: { send($0) })
          selfFinished()
        }
      )
    }
    return .init(merged: operations)
  }

  func runEscapingOperations(
    send: @escaping (Action) -> Void,
    onCompletion: @escaping () -> Void
  ) {
    let escapingCount = self.merged.filter(\.isEscaping).count
    guard escapingCount > 0
    else {
      onCompletion()
      return
    }
    let escapingCompleteCount = LockIsolated(0)
    for operation in self.merged {
      switch operation {
      case .async:
        continue
      case let .escaping(work):
        let childContinuation = EscapingSend<Action> { send($0) }
        childContinuation.onTermination { _ in
          escapingCompleteCount.withValue {
            $0 += 1
            if $0 == escapingCount {
              onCompletion()
            }
          }
        }
        work(childContinuation)
      }
    }
  }

  func runAsyncOperations(
    send: @escaping @MainActor (Action) -> Void
  ) async {
    guard self.merged.contains(where: \.isAsync)
    else { return }
    await withTaskGroup(of: Void.self) { group in
      for operation in self.merged {
        switch operation {
        case let .async(priority: priority, work):
          group.addTask(priority: priority) {
            await work(Send<Action> { send($0) })
          }
        case .escaping:
          continue
        }
      }
    }
  }

  public func onComplete(_ completion: @Sendable @escaping () -> Void) -> Self {
    let completedCount = LockIsolated(0)
    return .init(merged: self.merged.map { operation in
      switch operation {
      case let .async(priority: priority, work):
        return .async(priority: priority) { send in
          await work(send)
          completedCount.withValue {
            $0 += 1
            if $0 == self.merged.count {
              completion()
            }
          }
        }

      case let .escaping(work):
        return .escaping { send in
          send.onTermination { _ in 
            completedCount.withValue {
              $0 += 1
              if $0 == self.merged.count {
                completion()
              }
            }
          }
          work(send)
        }
      }
    })
  }

  public func map<T>(_ transform: @escaping (Action) -> T) -> NewEffect<T> {
    .init(merged: self.merged.map { operation in
      switch operation {
      case let .async(priority: priority, work):
        return .async(priority: priority) { send in
          await work(Send<Action> { action in send(transform(action)) })
        }

      case let .escaping(work):
        return .escaping { send in
          work(EscapingSend<Action> { action in send(transform(action)) })
        }
      }
    })
  }
}

public struct EscapingSend<Action>: Sendable {
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

extension NewEffect {
  @_spi(Internals)
  public var actions: AsyncStream<Action> {
    AsyncStream { continuation in
      let hasEscaping = self.merged.contains(where: \.isEscaping)
      let hasAsync = self.merged.contains(where: \.isAsync)
      let isEscapingFinished = LockIsolated(!hasEscaping)
      let isAsyncFinished = LockIsolated(!hasAsync)
      self.runEscapingOperations(send: { continuation.yield($0) }) {
        isEscapingFinished.withValue {
          $0 = true
          if $0 && isAsyncFinished.value {
            continuation.finish()
          }
        }
      }
      if hasAsync {
        Task {
          await self.runAsyncOperations(send: { continuation.yield($0) })
          isAsyncFinished.withValue {
            $0 = true
            if $0 && isEscapingFinished.value {
              continuation.finish()
            }
          }
        }
      }
    }
  }
}
