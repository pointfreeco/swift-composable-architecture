import Combine

extension Effect {
  /// Returns an effect that will be executed after given `dueTime`.
  ///
  /// ```swift
  /// case let .textChanged(text):
  ///   return self.apiClient.search(text)
  ///     .deferred(for: 0.5, scheduler: self.mainQueue)
  ///     .map(Action.searchResponse)
  /// ```
  ///
  /// - Parameters:
  ///   - dueTime: The duration you want to defer for.
  ///   - scheduler: The scheduler you want to deliver the defer output to.
  ///   - options: Scheduler options that customize the effect's delivery of elements.
  /// - Returns: An effect that will be executed after `dueTime`
  public func deferred<S: Scheduler>(
    for dueTime: S.SchedulerTimeType.Stride,
    scheduler: S,
    options: S.SchedulerOptions? = nil
  ) -> Self {
    switch self.operation {
    case .none:
      return .none
    case let .publisher(publisher):
      return Self(
        operation: .publisher(
          Just(())
            .setFailureType(to: Failure.self)
            .delay(for: dueTime, scheduler: scheduler, options: options)
            .flatMap { publisher.receive(on: scheduler) }
            .eraseToAnyPublisher()
        )
      )
    case let .run(priority, operation):
      return Self(
        operation: .run(priority) { send in
          do {
            try await scheduler.sleep(for: dueTime)
            await operation(send)
          } catch {}
        }
      )
    }
  }
}
