import Combine

extension Effect {
    /// Turns an effect into one that can be timeouted.
    ///
    /// To turn an effect into a timeout-able one you must provide an identifier, which is used to
    /// determine which in-flight effect should be canceled in order to start a new effect. Any
    /// hashable value can be used for the identifier, such as a string, but you can add a bit of
    /// protection against typos by defining a new type that conforms to `Hashable`, such as an empty
    /// struct:
    ///
    /// ```swift
    /// case let .textChanged(text):
    ///   struct SearchId: Hashable {}
    ///
    ///   return environment.search(text)
    ///     .timeout(id: SearchId(), for: 0.5, scheduler: environment.mainQueue, customError: {MyError.timeout)
    ///     .map(Action.searchResponse)
    /// ```
    ///
    /// - Parameters:
    ///   - id: The effect's identifier.
    ///   - dueTime: The duration you want to debounce for.
    ///   - scheduler: The scheduler you want to deliver the debounced output to.
    ///   - options: Scheduler options that customize the effect's delivery of elements.
    ///   - customError: A closure that executes if the Effect times out. The Effect sends the failure returned by this closure to the subscriber as the reason for termination.
    /// - Returns: An effect that publish customError only no value emit after a specified time elapses.
  public func timeout<S: Scheduler>(
    id: AnyHashable,
    for dueTime: S.SchedulerTimeType.Stride,
    scheduler: S,
    options: S.SchedulerOptions? = nil,
    customError: @escaping (() -> Self.Failure)
  ) -> Effect {
      timeout(dueTime, scheduler: scheduler, options: options, customError: customError)
      .eraseToEffect()
      .cancellable(id: id, cancelInFlight: true)
  }
}
