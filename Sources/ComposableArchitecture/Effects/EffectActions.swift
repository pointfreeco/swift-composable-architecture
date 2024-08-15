extension Effect {
  @_spi(Internals)
  public var actions: AsyncStream<Action> {
    switch self.operation {
    case .none:
      return .finished
    case let .sync(operation):
      return AsyncStream { continuation in
        let sendContinuation = Send.Continuation { action in
          continuation.yield(action)
        }
        sendContinuation.onTermination = { _ in
          continuation.finish()
        }
        continuation.onTermination = { _ in
          sendContinuation.finish()
        }
        operation(sendContinuation)
      }
    case let .run(priority, operation):
      return AsyncStream { continuation in
        let task = Task(priority: priority) {
          await operation(Send { action in continuation.yield(action) })
          continuation.finish()
        }
        continuation.onTermination = { _ in task.cancel() }
      }
    }
  }
}
