extension Effect {
  @_spi(Internals)
  public var actions: AsyncStream<Action> {
    AsyncStream { streamContinuation in
      let continuation = Send<Action>.Continuation { action in
        streamContinuation.yield(action)
      }
      continuation.onTermination { _ in
        if let async = self.operation.async {
          Task(priority: async.priority) {
            await async.operation(Send<Action> { action in
              streamContinuation.yield(action)
            })
            streamContinuation.finish()
          }
        } else {
          streamContinuation.finish()
        }
      }

      if let sync = self.operation.sync {
        sync(continuation)
      } else {
        continuation.finish()
      }
    }
  }
}
