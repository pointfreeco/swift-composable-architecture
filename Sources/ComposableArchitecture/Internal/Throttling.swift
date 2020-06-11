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

      guard scheduler.now.timeIntervalSince1970 - throttleTime.timeIntervalSince1970 < interval.timeInterval else {
        throttleTimes[id] = scheduler.now
        throttleValues[id] = nil
        return Observable.just(value)
      }

      let value = latest ? value : (throttleValues[id] as! Output? ?? value)
      throttleValues[id] = value

      return Observable.just(value)
        .delay(.seconds(throttleTime.addingTimeInterval(interval.timeInterval).timeIntervalSince1970 - scheduler.now.timeIntervalSince1970), scheduler: scheduler)
    }
    .eraseToEffect()
    .cancellable(id: id, cancelInFlight: true)
  }
}

var throttleTimes: [AnyHashable: Any] = [:]
var throttleValues: [AnyHashable: Any] = [:]

extension DispatchTimeInterval {
  var timeInterval: TimeInterval {
    switch self {
    case let .seconds(s):
      return TimeInterval(s)
    case let .milliseconds(ms):
      return TimeInterval(TimeInterval(ms) / 1000.0)
    case let .microseconds(us):
      return TimeInterval(Int64(us) * Int64(NSEC_PER_USEC)) / TimeInterval(NSEC_PER_SEC)
    case let .nanoseconds(ns):
      return TimeInterval(ns) / TimeInterval(NSEC_PER_SEC)
    case .never:
      return .infinity
    @unknown default:
      fatalError()
    }
  }

  static func seconds(_ interval: TimeInterval) -> DispatchTimeInterval {
    let delay = Double(NSEC_PER_SEC) * interval
    return DispatchTimeInterval.nanoseconds(Int(delay))
  }
}

