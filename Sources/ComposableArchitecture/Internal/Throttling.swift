import Dispatch
import Foundation
import RxSwift

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
  func throttle(
    id: AnyHashable,
    for interval: RxTimeInterval,
    scheduler: SchedulerType,
    latest: Bool
  ) -> Effect {
    self.flatMap { value -> Observable<Output> in
      guard let throttleTime = throttleTimes[id] as! RxTime? else {
        throttleTimes[id] = scheduler.now
        throttleValues[id] = nil
        return Observable.just(value)
      }

      guard let timeInterval = interval.timeInterval, throttleTime.timeIntervalSince(scheduler.now) < timeInterval else {
        throttleTimes[id] = scheduler.now
        throttleValues[id] = nil
        return Observable.just(value)
      }

      let value = latest ? value : (throttleValues[id] as! Output? ?? value)
      throttleValues[id] = value

      return Observable.just(value)
        .delay(
            .milliseconds(Int(scheduler.now.timeIntervalSince(throttleTime.addingTimeInterval(timeInterval)) * 1000.0)),
            scheduler: scheduler
        )
    }
    .eraseToEffect()
    .cancellable(id: id, cancelInFlight: true)
  }
}

var throttleTimes: [AnyHashable: Any] = [:]
var throttleValues: [AnyHashable: Any] = [:]

extension DispatchTimeInterval {
    var timeInterval: TimeInterval? {
        switch self {
        case .seconds(let value):
            return TimeInterval(value)
        case .milliseconds(let value):
            return TimeInterval(value) * 0.001
        case .microseconds(let value):
            return TimeInterval(value) * 0.000001
        case .nanoseconds(let value):
           return TimeInterval(value) * 0.000000001
        case .never:
            return nil
        @unknown default:
            return nil
        }
    }
}
