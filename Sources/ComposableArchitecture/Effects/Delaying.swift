import Combine

extension Effect {
  /// Returns an effect that will be executed after given `dueTime`.
  ///
  /// To create a deferred effect, you must provide an identifier, which is used to
  /// identify which in-flight effect should be canceled. Any hashable
  /// value can be used for the identifier, such as a string, but you can add a bit of protection
  /// against typos by defining a new type that conforms to `Hashable`, such as an empty struct:
  ///
  ///
  ///     case let .textChanged(text):
  ///       struct SearchId: Hashable {}
  ///
  ///       return environment.search(text)
  ///         .map(Action.searchResponse)
  ///         .delay(for: 0.5, scheduler: environment.mainQueue)
  ///
  /// - Parameters:
  ///   - upstream: the effect you want to delay.
  ///   - dueTime: The duration you want to delay for.
  ///   - scheduler: The scheduler you want to deliver the delay output to.
  ///   - options: Scheduler options that customize the effect's delivery of elements.
  /// - Returns: An effect that will be executed after `dueTime`
  public func deferred<S: Scheduler>(
    for dueTime: S.SchedulerTimeType.Stride,
    scheduler: S,
    options: S.SchedulerOptions? = nil
  ) -> Effect {
    Just(())
      .setFailureType(to: Failure.self)
      .delay(for: dueTime, scheduler: scheduler, options: options)
      .flatMap { self }
      .eraseToEffect()
  }
}

