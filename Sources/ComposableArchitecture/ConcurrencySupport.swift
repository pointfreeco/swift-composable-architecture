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

@dynamicMemberLookup
public final actor SendableState<Value> {
  public var value: Value

  public init(_ wrappedValue: Value) {
    self.value = wrappedValue
  }

  public subscript<Subject>(dynamicMember keyPath: KeyPath<Value, Subject>) -> Subject {
    self.value[keyPath: keyPath]
  }

  public func modify<R>(_ operation: (inout Value) async throws -> R) async rethrows -> R {
    var wrappedValue = self.value
    let returnValue = try await operation(&wrappedValue)
    self.value = wrappedValue
    return returnValue
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

  public static func streamWithContinuation() -> (stream: Self, continuation: Continuation) {
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

  public static func streamWithContinuation() -> (stream: Self, continuation: Continuation) {
    var continuation: Continuation!
    return (Self { continuation = $0 }, continuation)
  }
}

extension Task where Failure == Never {
  public static func never() async throws -> Success {
    let stream = AsyncStream<Success> { _ in }
    for await element in stream {
      return element
    }
    throw _Concurrency.CancellationError()
  }
}

// TODO: Move to combine-schedulers

extension Scheduler {
  @available(iOS 15.0, *)
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

