import Combine
import Dispatch

extension Effect {
  /// Throttles an effect so that it only publishes one output per given interval.
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
    self.throttle(id: id, for: interval, scheduler: scheduler, strategy: latest ? .latest : .first)
  }

  /// Throttles an effect so that it only publishes one output per given interval.
  ///
  /// - Parameters:
  ///   - id: The effect's identifier.
  ///   - interval: The interval at which to find and emit each element, expressed in the time
  ///   system of the scheduler.
  ///   - scheduler: The scheduler you want to deliver the throttled output to.
  ///   - strategy: The strategy used do determine the final element to emit from all elements
  ///   received during each interval.
  /// - Returns: An effect that only emits one element during the specified interval according to
  /// the defined strategy.
  public func throttle<S, T>(
    id: AnyHashable,
    for interval: S.SchedulerTimeType.Stride,
    scheduler: S,
    strategy: ThrottleStrategy<T, Output>
  ) -> Effect<T, Failure> where S: Scheduler {
    self.receive(on: scheduler)
      .flatMap { value -> AnyPublisher<T, Failure> in
        throttleLock.lock()
        defer { throttleLock.unlock() }

        guard let throttleTime = throttleTimes[id] as! S.SchedulerTimeType? else {
          throttleTimes[id] = scheduler.now
          throttleValues[id] = nil
          let value = strategy.nextValue(nil, value)
          return Just(value).setFailureType(to: Failure.self).eraseToAnyPublisher()
        }

        let value = strategy.nextValue(throttleValues[id] as! T?, value)
        throttleValues[id] = value

        guard throttleTime.distance(to: scheduler.now) < interval else {
          throttleTimes[id] = scheduler.now
          throttleValues[id] = nil
          return Just(value).setFailureType(to: Failure.self).eraseToAnyPublisher()
        }

        return Just(value)
          .delay(
            for: scheduler.now.distance(to: throttleTime.advanced(by: interval)),
            scheduler: scheduler
          )
          .handleEvents(
            receiveOutput: { _ in
              throttleLock.sync {
                throttleTimes[id] = scheduler.now
                throttleValues[id] = nil
              }
            }
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
let throttleLock = NSRecursiveLock()

extension Effect {

  /// A witness type that wraps an accumulating `nextValue` closure which defines a strategy to
  /// apply to received values in `Effect.throttle` operations, in order to determine the final
  /// value to return for each throttled interval.
  ///
  /// The `nextValue` closure combines an accumulating value `T?` with each received value `U` to
  /// produce a new throttled value `T`, resembling a `reduce`.
  public struct ThrottleStrategy<T, U> {

    /// The closure that produces the next value for each received value during the throttled
    /// interval.
    public var nextValue: (T?, U) -> T

    /// Initializes a throttle strategy from an accumulating closure.
    /// - Parameter nextValue: The closure that produces the next value for each received value
    /// during the throttled interval.
    public init(nextValue: @escaping (T?, U) -> T) {
      self.nextValue = nextValue
    }
  }
}

extension Effect.ThrottleStrategy where T == U {

  /// A strategy that returns the **first** value received during _each_ throttle interval.
  public static var first: Self { .init { $0 ?? $1 } }

  /// A strategy that returns the **latest** value received during _each_ throttle interval.
  public static var latest: Self { .init { $1 } }
}

extension Effect.ThrottleStrategy where T == [U] {

  /// A strategy that returns **all** values received during _each_ throttle interval, in order.
  public static var collect: Self { .init { ($0 ?? []) + [$1] } }
}
