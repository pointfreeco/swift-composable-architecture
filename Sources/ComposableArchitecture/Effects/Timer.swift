import RxSwift
import Foundation

extension Effect where Output: RxAbstractInteger {
  /// Returns an effect that repeatedly emits the current time of the given
  /// scheduler on the given interval.
  ///
  /// This effect serves as a testable alternative to `Timer.publish`, which
  /// performs its work on a run loop, _not_ a scheduler.
  ///
  ///     struct TimerId: Hashable {}
  ///
  ///     switch action {
  ///     case .startTimer:
  ///       return Effect.timer(id: TimerId(), every: 1, on: environment.scheduler)
  ///         .map { .timerUpdated($0) }
  ///     case let .timerUpdated(date):
  ///       state.date = date
  ///       return .none
  ///     case .stopTimer:
  ///       return .cancel(id: TimerId())
  ///
  /// - Parameters:
  ///   - interval: The time interval on which to publish events. For example, a value of `0.5`
  ///     publishes an event approximately every half-second.
  ///   - scheduler: The scheduler on which the timer runs.
  ///   - tolerance: The allowed timing variance when emitting events. Defaults to `nil`, which
  ///     allows any variance.
  ///   - options: Scheduler options passed to the timer. Defaults to `nil`.
  public static func timer(
    id: AnyHashable,
    every interval: RxTimeInterval,
    on scheduler: SchedulerType
  ) -> Effect  {

    return Observable
    .interval(interval, scheduler: scheduler)
    .eraseToEffect()
    .cancellable(id: id)
  }
}
