extension Effect {
  @_spi(Internals)
  public var actions: AsyncStream<Action> {
    AsyncStream { streamContinuation in
      let syncCount = self.operations.filter { $0.sync != nil }.count
      let syncCompleteCount = LockIsolated(0)

      // TODO: rewrite because sync can finish before all asycns have been catalogued

      for operation in self.operations {
        if let sync = operation.sync {
          let continuation = Send<Action>.Continuation { streamContinuation.yield($0) }
          continuation.onTermination { _ in
            syncCompleteCount.withValue {
              $0 += 1
              if syncCount == $0 {
                Task {
                  await withTaskGroup(of: Void.self) { group in
                    for operation in self.operations {
                      guard let async = operation.async else { continue }
                      group.addTask {
                        await async.operation(Send<Action> { streamContinuation.yield($0) })
                      }
                    }
                  }
                  streamContinuation.finish()
                }
              }
            }
          }
          sync(continuation)
        }
      }
      if syncCount == 0 {
        Task {
          await withTaskGroup(of: Void.self) { group in
            for operation in self.operations {
              guard let async = operation.async else { continue }
              group.addTask {
                await async.operation(Send<Action> { streamContinuation.yield($0) })
              }
            }
          }
          streamContinuation.finish()
        }
      }
    }

//      let continuation = Send<Action>.Continuation { action in
//        streamContinuation.yield(action)
//      }
//      continuation.onTermination { _ in
//        if let async = self.operation.async {
//          Task(priority: async.priority) {
//            await async.operation(Send<Action> { action in
//              streamContinuation.yield(action)
//            })
//            streamContinuation.finish()
//          }
//        } else {
//          streamContinuation.finish()
//        }
//      }
//
//      if let sync = self.operation.sync {
//        sync(continuation)
//      } else {
//        continuation.finish()
//      }
//    }
  }
}
