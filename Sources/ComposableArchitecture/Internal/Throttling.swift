import Combine
import Dispatch

extension Effect {
  /// Turns an effect into one that can be throttled.
  ///
  /// - Parameters:
  ///   - id: The effect's identifier.
  ///   - interval: The interval at which to find and emit the most recent element, expressed in
  ///     the time system of the scheduler.
  ///   - scheduler: The scheduler you want to deliver the throttled output to.
  ///   - latest: A boolean value that indicates whether to publish the most recent element. If
  ///     `false`, the publisher emits the first element received during the interval.
  /// - Returns: An effect that emits either the most-recent or first element received during the
  ///   specified interval.
  func throttle<S>(
    id: AnyHashable,
    for interval: S.SchedulerTimeType.Stride,
    scheduler: S,
    latest: Bool
  ) -> Effect where S: Scheduler {
    self.flatMap { value -> AnyPublisher<Output, Failure> in
      guard let throttleTime = throttleTimes[id] as! S.SchedulerTimeType? else {
        throttleTimes[id] = scheduler.now
        throttleValues[id] = nil
        return Just(value).setFailureType(to: Failure.self).eraseToAnyPublisher()
      }

      guard throttleTime.distance(to: scheduler.now) < interval else {
        throttleTimes[id] = scheduler.now
        throttleValues[id] = nil
        return Just(value).setFailureType(to: Failure.self).eraseToAnyPublisher()
      }

      let value = latest ? value : (throttleValues[id] as! Output? ?? value)
      throttleValues[id] = value

      return Just(value)
        .delay(
          for: scheduler.now.distance(to: throttleTime.advanced(by: interval)), scheduler: scheduler
        )
        .setFailureType(to: Failure.self)
        .eraseToAnyPublisher()
    }
    .eraseToEffect()
    .cancellable(id: id, cancelInFlight: true)
  }
}

var throttleTimes: [AnyHashable: Any] = [:]
var throttleValues: [AnyHashable: Any] = [:]
