import _CAsyncSupport

@_spi(Internals) public func _withMainSerialExecutor<T>(
  @_implicitSelfCapture operation: () async throws -> T
) async rethrows -> T {
  let hook = swift_task_enqueueGlobal_hook
  defer { swift_task_enqueueGlobal_hook = hook }
  swift_task_enqueueGlobal_hook = { job, original in
    MainActor.shared.enqueue(unsafeBitCast(job, to: UnownedJob.self))
  }
  return try await operation()
}
