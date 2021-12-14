import CombineSchedulers

extension TestScheduler {
  @MainActor
  public func advance(by stride: SchedulerTimeType.Stride = .zero) async {
    await Task.yield()
    _ = { self.advance(by: stride) }()
  }

  @MainActor
  public func run() async {
    await Task.yield()
    _ = { self.run() }()
  }
}

// MARK: - swift-concurrency-helpers

import XCTestDynamicOverlay
import Combine

extension AsyncThrowingStream where Failure == Error {
  public static func pipe() -> (Self.Continuation, Self) {
    var c: Continuation!
    let s = Self { c = $0 }
    return (c, s)
  }
}

// TODO: AsyncStream.empty(completeImmediately:), .yielding, .throwing, 

extension AsyncThrowingStream where Failure == Error {
  public static func failing(_ message: String) -> Self {
    .init(
      unfolding: {
        XCTFail("Unimplemented: \(message)")
        return nil
      }
    )
  }
}

extension AsyncThrowingStream {
  public init(_ build: @escaping (Continuation) async -> Void) {
    let t = { (continuation: Continuation) -> Void in
      Task {
        await build(continuation)
      }
    }
    self = .init(t)
  }
}

extension Effect {
  public init<S: AsyncSequence>(
    // TODO: remove priority?
    priority: TaskPriority? = nil,
    _ sequence: S
  )
  where
  S.Element == Output,
  Failure == Error
  {
    let subject = PassthroughSubject<Output, Failure>()

    let task = Task(priority: priority) {
      do {
        try await withTaskCancellationHandler {
          subject.send(completion: .finished)
        } operation: {
          for try await element in sequence {
            subject.send(element)
          }
          subject.send(completion: .finished)
        }
      } catch {
        subject.send(completion: .failure(error))
      }
    }

    self = subject
      .handleEvents(receiveCancel: task.cancel)
      .eraseToEffect()
  }
}
