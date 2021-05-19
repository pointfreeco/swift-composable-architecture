import Combine

extension Effect {
  internal func pending<S: Scheduler>(
    id: AnyHashable,
    for dueTime: S.SchedulerTimeType.Stride,
    scheduler: S,
    options: S.SchedulerOptions? = nil,
    cancelInFlight: Bool = true
  ) -> Effect {
    Just(())
      .setFailureType(to: Failure.self)
      .delay(for: dueTime, scheduler: scheduler, options: options)
      .flatMap { upstream }
      .eraseToEffect()
      .cancellable(id: id, cancelInFlight: cancelInFlight)
  }
}

