#if canImport(Combine)
  @preconcurrency import Combine
#else
  @preconcurrency import OpenCombine
#endif

extension Effect where Action: Sendable {
  @_spi(Internals) public var actions: AsyncStream<Action> {
    switch self.operation {
    case .none:
      return .finished
    case .publisher(let publisher):
      return AsyncStream { continuation in
        let cancellable = publisher.sink(
          receiveCompletion: { _ in continuation.finish() },
          receiveValue: { continuation.yield($0) }
        )
        continuation.onTermination = { _ in
          cancellable.cancel()
        }
      }
    case .run(let name, let priority, let operation):
      return AsyncStream { continuation in
        let task = Task(name: name, priority: priority) {
          await operation(Send { action in continuation.yield(action) })
          continuation.finish()
        }
        continuation.onTermination = { _ in task.cancel() }
      }
    }
  }
}
