import Combine
import Dispatch
import Foundation

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
  public func throttle<ID: Hashable, S: Scheduler>(
    id: ID,
    for interval: S.SchedulerTimeType.Stride,
    scheduler: S,
    latest: Bool
  ) -> Self {
    switch self.operation {
    case .none:
      return .none

    case let .run(_, operation):
      return .run { send in
        await operation(Send<Action>.init(send: { action in
          throttleLock.lock()
          defer { throttleLock.unlock() }
          guard let throttleTime = throttleTimes[id] as! S.SchedulerTimeType? else {
            throttleTimes[id] = scheduler.now
            throttleValues[id] = nil
            throttleTasks[id] = nil
            send(action)
            return
          }

          let value = latest ? action : (throttleValues[id] as! Action? ?? action)
          throttleValues[id] = value

          guard throttleTime.distance(to: scheduler.now) < interval else {
            throttleTimes[id] = scheduler.now
            throttleValues[id] = nil
            throttleTasks[id] = nil
            send(action)
            return
          }

          throttleTasks[id]?.cancel()
          throttleTasks[id] = Task {
            try await scheduler.sleep(for: scheduler.now.distance(to: throttleTime.advanced(by: interval)))
            _ = { throttleLock.lock() }()
            defer { _ = { throttleLock.unlock() }() }
            send(action)
            throttleTimes[id] = scheduler.now
            throttleValues[id] = nil
            throttleTasks[id] = nil
          }
        }))
      }

    case let .publisher(publisher):
      return .publisher {
        publisher
          .receive(on: scheduler)
          .flatMap { value -> AnyPublisher<Action, Never> in
            throttleLock.lock()
            defer { throttleLock.unlock() }

            guard let throttleTime = throttleTimes[id] as! S.SchedulerTimeType? else {
              throttleTimes[id] = scheduler.now
              throttleValues[id] = nil
              return Just(value).eraseToAnyPublisher()
            }

            let value = latest ? value : (throttleValues[id] as! Action? ?? value)
            throttleValues[id] = value

            guard throttleTime.distance(to: scheduler.now) < interval else {
              throttleTimes[id] = scheduler.now
              throttleValues[id] = nil
              return Just(value).eraseToAnyPublisher()
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
              .eraseToAnyPublisher()
          }
      }
      .cancellable(id: id, cancelInFlight: true)
    }
  }

  /// Throttles an effect so that it only publishes one output per given interval.
  ///
  /// A convenience for calling ``EffectPublisher/throttle(id:for:scheduler:latest:)-3gibe`` with a
  /// static type as the effect's unique identifier.
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
  public func throttle<S: Scheduler>(
    id: Any.Type,
    for interval: S.SchedulerTimeType.Stride,
    scheduler: S,
    latest: Bool
  ) -> Self {
    self.throttle(id: ObjectIdentifier(id), for: interval, scheduler: scheduler, latest: latest)
  }
}

var throttleTimes: [AnyHashable: Any] = [:]
var throttleValues: [AnyHashable: Any] = [:]
var throttleTasks: [AnyHashable: Task<Void, Error>] = [:]
let throttleLock = NSRecursiveLock()
