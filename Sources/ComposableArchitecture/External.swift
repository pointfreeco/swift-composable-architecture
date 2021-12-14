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

// swift-concurrency-helpers
// swift-concurrency-tools
// swift-concurrency-extensions

import XCTestDynamicOverlay

extension AsyncStream {
  public init(_ build: @escaping (Continuation) async -> Void) {
    self.init { continuation in
      Task {
        await build(continuation)
        continuation.finish()
      }
    }
  }

  // TODO: Is this name right for vanilla?
  public static func passthrough() -> (continuation: Continuation, stream: Self) {
    var continuation: Continuation!
    let stream = Self { continuation = $0 }
    return (continuation, stream)
  }

  public static func yielding(_ element: Element) -> Self {
    Self {
      $0.yield(element)
      $0.finish()
    }
  }

  // TODO: Is this name right for vanilla?
  public static func empty(finishImmediately: Bool = true) -> Self {
    self.init {
      if finishImmediately {
        $0.finish()
      }
    }
  }

  public static func failing(_ message: String) -> Self {
    .init {
      XCTFail("Unimplemented: \(message)")
      return nil
    }
  }
}

extension AsyncThrowingStream where Failure == Error {
  public init(_ build: @escaping (Continuation) async throws -> Void) {
    self.init { continuation in
      Task {
        do {
          try await build(continuation)
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
    }
  }

  // TODO: Is this name right for vanilla?
  public static func passthrough() -> (continuation: Continuation, stream: Self) {
    var continuation: Continuation!
    let stream = Self { continuation = $0 }
    return (continuation, stream)
  }

  public static func yielding(_ element: Element) -> Self {
    Self {
      $0.yield(element)
      $0.finish()
    }
  }

  public static func throwing(_ error: Error) -> Self {
    self.init { $0.finish(throwing: error) }
  }

  // TODO: Is this name right for vanilla?
  public static func empty(finishImmediately: Bool = true) -> Self {
    self.init {
      if finishImmediately {
        $0.finish()
      }
    }
  }

  public static func failing(_ message: String) -> Self {
    .init {
      XCTFail("Unimplemented: \(message)")
      return nil
    }
  }
}

#if canImport(Combine)
  import Combine

  extension AsyncStream {
    public var publisher: AnyPublisher<Element, Never> {
      let subject = PassthroughSubject<Element, Never>()

      let task = Task {
        await withTaskCancellationHandler {
          subject.send(completion: .finished)
        } operation: {
          for await element in self {
            subject.send(element)
          }
          subject.send(completion: .finished)
        }
      }

      return subject
        .handleEvents(receiveCancel: task.cancel)
        .eraseToAnyPublisher()
    }
  }

  extension AsyncSequence {
    public var publisher: AnyPublisher<Element, Error> {
      let subject = PassthroughSubject<Element, Error>()

      let task = Task {
        do {
          try await withTaskCancellationHandler {
            subject.send(completion: .finished)
          } operation: {
            for try await element in self {
              subject.send(element)
            }
            subject.send(completion: .finished)
          }
        } catch {
          subject.send(completion: .failure(error))
        }
      }

      return subject
        .handleEvents(receiveCancel: task.cancel)
        .eraseToAnyPublisher()
    }
  }
#endif
