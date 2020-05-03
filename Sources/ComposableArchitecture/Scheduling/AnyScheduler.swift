import Combine
import Foundation

/// A type-erasing scheduler that defines when and how to execute a closure.
public struct AnyScheduler<SchedulerTimeType, SchedulerOptions>: Scheduler
where
  SchedulerTimeType: Strideable,
  SchedulerTimeType.Stride: SchedulerTimeIntervalConvertible
{

  private let _minimumTolerance: () -> SchedulerTimeType.Stride
  private let _now: () -> SchedulerTimeType
  private let _scheduleAfterIntervalToleranceSchedulerOptionsAction:
    (
      SchedulerTimeType,
      SchedulerTimeType.Stride,
      SchedulerTimeType.Stride,
      SchedulerOptions?,
      @escaping () -> Void
    ) -> Cancellable
  private let _scheduleAfterToleranceSchedulerOptionsAction:
    (
      SchedulerTimeType,
      SchedulerTimeType.Stride,
      SchedulerOptions?,
      @escaping () -> Void
    ) -> Void
  private let _scheduleSchedulerOptionsAction: (SchedulerOptions?, @escaping () -> Void) -> Void

  /// The minimum tolerance allowed by the scheduler.
  public var minimumTolerance: SchedulerTimeType.Stride { self._minimumTolerance() }

  /// This scheduler’s definition of the current moment in time.
  public var now: SchedulerTimeType { self._now() }

  let scheduler: Any

  /// Creates a type-erasing scheduler to wrap the provided scheduler.
  ///
  /// - Parameters:
  ///   - scheduler: A scheduler to wrap with a type-eraser.
  public init<S>(
    _ scheduler: S
  )
  where
    S: Scheduler, S.SchedulerTimeType == SchedulerTimeType, S.SchedulerOptions == SchedulerOptions
  {
    self.scheduler = scheduler
    self._now = { scheduler.now }
    self._minimumTolerance = { scheduler.minimumTolerance }
    self._scheduleAfterToleranceSchedulerOptionsAction = scheduler.schedule
    self._scheduleAfterIntervalToleranceSchedulerOptionsAction = scheduler.schedule
    self._scheduleSchedulerOptionsAction = scheduler.schedule
  }

  /// Performs the action at some time after the specified date.
  public func schedule(
    after date: SchedulerTimeType,
    tolerance: SchedulerTimeType.Stride,
    options: SchedulerOptions?,
    _ action: @escaping () -> Void
  ) {
    self._scheduleAfterToleranceSchedulerOptionsAction(date, tolerance, options, action)
  }

  /// Performs the action at some time after the specified date, at the
  /// specified frequency, taking into account tolerance if possible.
  public func schedule(
    after date: SchedulerTimeType,
    interval: SchedulerTimeType.Stride,
    tolerance: SchedulerTimeType.Stride,
    options: SchedulerOptions?,
    _ action: @escaping () -> Void
  ) -> Cancellable {
    self._scheduleAfterIntervalToleranceSchedulerOptionsAction(
      date, interval, tolerance, options, action)
  }

  /// Performs the action at the next possible opportunity.
  public func schedule(
    options: SchedulerOptions?,
    _ action: @escaping () -> Void
  ) {
    self._scheduleSchedulerOptionsAction(options, action)
  }
}

/// A convenience type to specify an `AnyScheduler` by the scheduler it wraps rather than by the
/// time type and options type.
public typealias AnySchedulerOf<Scheduler> = AnyScheduler<
  Scheduler.SchedulerTimeType, Scheduler.SchedulerOptions
> where Scheduler: Combine.Scheduler

extension Scheduler {
  /// Wraps this scheduler with a type eraser.
  public func eraseToAnyScheduler() -> AnyScheduler<SchedulerTimeType, SchedulerOptions> {
    AnyScheduler(self)
  }
}
