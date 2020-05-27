import Combine
import Foundation

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
  public func throttle<S>(
    id: AnyHashable,
    for interval: S.SchedulerTimeType.Stride,
    scheduler: S,
    latest: Bool
  ) -> Effect where S: Scheduler {

    let throttleId =
      (scheduler as? AnySchedulerOf<S>)
      .map { Throttle(id: id, schedulerId: ObjectIdentifier($0.scheduler as AnyObject)) }
      ?? id

    let effect = self.flatMap { value -> AnyPublisher<Output, Failure> in
      throttlesLock.lock()
      defer { throttlesLock.unlock() }

      guard
        let throttleTime = throttleTimes[throttleId] as! S.SchedulerTimeType?,
        throttleTime.distance(to: scheduler.now) < interval
      else {
        throttleTimes[throttleId] = scheduler.now
        throttleValues[throttleId] = nil
        return Just(value)
          .receive(on: scheduler)
          .setFailureType(to: Failure.self)
          .eraseToAnyPublisher()
      }

      let value = latest ? value : (throttleValues[throttleId] as! Output? ?? value)
      throttleValues[throttleId] = value

      return Just(value)
        .delay(
          for: scheduler.now.distance(to: throttleTime.advanced(by: interval)), scheduler: scheduler
        )
        .setFailureType(to: Failure.self)
        .eraseToAnyPublisher()
    }
    .eraseToEffect()
    .cancellable(id: throttleId, cancelInFlight: true)

    return id == throttleId ? effect : effect.cancellable(id: id)
  }
}

private struct Throttle: Hashable {
  let id: AnyHashable
  let schedulerId: ObjectIdentifier
}

private var throttlesLock = NSRecursiveLock()
private var throttleTimes: [AnyHashable: Any] = [:]
private var throttleValues: [AnyHashable: Any] = [:]
