import Combine

// NB: From SE-0302
@propertyWrapper
public struct UncheckedSendable<Wrapped> : @unchecked Sendable {
  public var wrappedValue: Wrapped

  public init(wrappedValue: Wrapped) {
    self.wrappedValue = wrappedValue
  }

  public var unchecked: Wrapped {
    _read { yield self.wrappedValue }
    _modify { yield &self.wrappedValue }
  }

  public var projectedValue: Self {
    get { self }
    set { self = newValue }
  }
}

@propertyWrapper
public final class Box<Wrapped> {
  public var wrappedValue: Wrapped

  public init(wrappedValue: Wrapped) {
    self.wrappedValue = wrappedValue
  }

  public var unboxed: Wrapped {
    _read { yield self.wrappedValue }
    _modify { yield &self.wrappedValue }
  }

  public var projectedValue: Box<Wrapped> {
    self
  }
}

extension AsyncStream {
  public init<S: AsyncSequence>(_ sequence: S) where S.Element == Element {
    self.init { (continuation: Continuation) in
      let task = Task {
        do {
          for try await element in sequence {
            continuation.yield(element)
          }
        } catch {}
        continuation.finish()
      }
      continuation.onTermination = { _ in
        task.cancel()
      }
    }
  }

  // FIXME: Better name than ReactiveSwift-inspired 'pipe'?
  public static func pipe() -> (stream: Self, continuation: Continuation) {
    var continuation: Continuation!
    return (Self { continuation = $0 }, continuation)
  }
}

extension AsyncThrowingStream where Failure == Error {
  public init<S: AsyncSequence>(_ sequence: S) where S.Element == Element {
    self.init { (continuation: Continuation) in
      let task = Task {
        do {
          for try await element in sequence {
            continuation.yield(element)
          }
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
      continuation.onTermination = { _ in
        task.cancel()
      }
    }
  }

  // FIXME: Better name than ReactiveSwift-inspired 'pipe'?
  public static func pipe() -> (stream: Self, continuation: Continuation) {
    var continuation: Continuation!
    return (Self { continuation = $0 }, continuation)
  }
}

extension Scheduler {
  public func sleep(
    for interval: SchedulerTimeType.Stride,
    tolerance: SchedulerTimeType.Stride? = nil,
    options: SchedulerOptions? = nil
  ) async throws {
    try Task.checkCancellation()
    await Just(())
      .delay(for: interval, tolerance: tolerance, scheduler: self, options: options)
      .values
      .first { _ in true }
    try Task.checkCancellation()
  }
}
