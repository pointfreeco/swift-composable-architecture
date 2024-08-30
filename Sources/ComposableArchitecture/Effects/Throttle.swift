@preconcurrency import Combine
import Dispatch
import Foundation

extension Effect where Action: Sendable {
  /// Throttles an effect so that it only publishes one output per given interval.
  ///
  /// The throttling of an effect is with respect to actions being sent into the store. So, if
  /// you return a throttled effect from an action that is sent with high frequency, the effect
  /// will be executed at most once per interval specified.
  ///
  /// > Note: It is usually better to perform throttling logic in the _view_ in order to limit
  /// the number of actions sent into the system. Only use this operator if your reducer needs to
  /// layer on specialized logic for throttling. See <doc:Performance> for more information of why
  /// sending high-frequency actions into a store is typically not what you want to do.
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
  public func throttle<S: Scheduler & Sendable>(
    id: some Hashable & Sendable,
    for interval: S.SchedulerTimeType.Stride,
    scheduler: S,
    latest: Bool
  ) -> Self
  where S.SchedulerTimeType.Stride: Sendable {
    switch self.operation {
    case .none:
      return .none

    case .run:
      return .publisher { _EffectPublisher(self) }
        .throttle(id: id, for: interval, scheduler: scheduler, latest: latest)

    case let .publisher(publisher):
      return .publisher {
        publisher
          .receive(on: scheduler)
          .flatMap { value -> AnyPublisher<Action, Never> in
            throttleState.withValue {
              guard let throttleTime = $0.times[id] as! S.SchedulerTimeType? else {
                $0.times[id] = scheduler.now
                $0.values[id] = nil
                return Just(value).eraseToAnyPublisher()
              }

              let value = latest ? value : ($0.values[id] as! Action? ?? value)
              $0.values[id] = value

              guard throttleTime.distance(to: scheduler.now) < interval else {
                $0.times[id] = scheduler.now
                $0.values[id] = nil
                return Just(value).eraseToAnyPublisher()
              }

              return Just(value)
                .delay(
                  for: scheduler.now.distance(to: throttleTime.advanced(by: interval)),
                  scheduler: scheduler
                )
                .handleEvents(
                  receiveOutput: { _ in
                    throttleState.withValue {
                      $0.times[id] = scheduler.now
                      $0.values[id] = nil
                    }
                  }
                )
                .eraseToAnyPublisher()
            }
          }
      }
      .cancellable(id: id, cancelInFlight: true)
    }
  }
}

private let throttleState = LockIsolated<(times: [AnyHashable: Any], values: [AnyHashable: Any])>(
  (times: [:], values: [:])
)
