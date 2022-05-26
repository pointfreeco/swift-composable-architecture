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

  public static func pipe() -> (stream: Self, continuation: Continuation) {
    var continuation: Continuation!
    return (Self { continuation = $0 }, continuation)
  }
}
