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

  static func publisher(_ createPublisher: @escaping () -> some Publisher<Action, Never>) -> Self {
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
    }
  }
  static func sync(_ work: @escaping (EscapingSend<Action>) -> Void) -> Self {
    .escaping { send in
      work(send)
      send.finish()
    }
  }
  static var never: Self {
    .escaping { _ in }
  }
  static var finished: Self {
    .escaping { $0.finish() }
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

  static func async(priority: TaskPriority?, operation: @escaping (Send<Action>) async -> Void) -> Self {
    .init(.async(priority: priority, operation))
  }
  static func sync(_ work: @escaping (EscapingSend<Action>) -> Void) -> Self {
    .init(.sync(work))
  }
  static func publisher(_ createPublisher: @escaping () -> some Publisher<Action, Never>) -> Self {
    .init(.publisher(createPublisher))
  }
  func merge(with other: Self) -> Self {
    .init(merged: self.merged + other.merged)
  }
  func concat(with other: Self) -> Self {
    func runSyncs(
      effect: NewEffect<Action>,
      continuation: @escaping (Action) -> Void,
      onCompletion: @escaping () -> Void
    ) {
      let escapingCount = effect.merged.filter(\.isEscaping).count
      let syncCompleteCount = LockIsolated(0)
      for operation in effect.merged {
        switch operation {
        case .async:
          continue
        case let .escaping(work):
          let childContinuation = EscapingSend<Action> { continuation($0) }
          childContinuation.onTermination { _ in
            syncCompleteCount.withValue {
              $0 += 1
              if $0 == escapingCount {
                onCompletion()
              }
            }
          }
          work(childContinuation)
        }
      }
      if escapingCount == 0 {
        onCompletion()
      }
    }

    return .sync { send in
      runSyncs(effect: self, continuation: { send($0) }) {
        
      }
    }

//    return .async(priority: nil) { send in
//      interpret(self, send: { send($0) }) {
//        interpret(other, send: { send($0) }, onComplete: { })
//      }
//    }
  }
}

func interpret<Action>(
  _ effect: NewEffect<Action>,
  send: @escaping (Action) -> Void,
  onComplete: @Sendable @escaping () -> Void
) {
  let completeCount = LockIsolated(0)
  let totalCount = effect.merged.count
  for operation in effect.merged {
    switch operation {
    case let .async(priority: priority, work):
      Task(priority: priority) {
        await work(Send<Action> { send($0) })
        completeCount.withValue {
          $0 += 1
          if completeCount.value == totalCount {
            onComplete()
          }
        }
      }

    case let .escaping(work):
      let send = EscapingSend<Action> { send($0) }
      send.onTermination { _ in
        completeCount.withValue {
          $0 += 1
          if completeCount.value == totalCount {
            onComplete()
          }
        }
      }
      work(send)
    }
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
