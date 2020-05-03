import Combine
import Foundation

/// A scheduler whose current time and execution can be controlled in a deterministic manner.
public final class TestScheduler<SchedulerTimeType, SchedulerOptions>: Scheduler
where SchedulerTimeType: Strideable, SchedulerTimeType.Stride: SchedulerTimeIntervalConvertible {

  public let minimumTolerance: SchedulerTimeType.Stride = .zero
  public private(set) var now: SchedulerTimeType
  private var scheduled: [(id: UUID, date: SchedulerTimeType, action: () -> Void)] = []

  /// Creates a test scheduler with the given date.
  ///
  /// - Parameter now: The current date of the test scheduler.
  public init(now: SchedulerTimeType) {
    self.now = now
  }

  /// Advances the scheduler by the given stride.
  ///
  /// - Parameter stride: A stride.
  public func advance(by stride: SchedulerTimeType.Stride = .zero) {
    self.scheduled = self.scheduled
      // NB: Stabilizes sort via offset.
      .enumerated()
      .sorted(by: { $0.element.date < $1.element.date || $0.offset < $1.offset })
      .map { $0.element }

    guard
      let nextDate = self.scheduled.first?.date,
      self.now.advanced(by: stride) >= nextDate
    else {
      self.now = self.now.advanced(by: stride)
      return
    }

    let delta = self.now.distance(to: nextDate)
    self.now = nextDate

    while let (_, date, action) = self.scheduled.first, date == nextDate {
      action()
      self.scheduled.removeFirst()
    }

    self.advance(by: stride - delta)
  }

  /// Runs the scheduler until it has no scheduled items left.
  public func run() {
    while let date = self.scheduled.first?.date {
      self.advance(by: self.now.distance(to: date))
    }
  }

  public func schedule(
    after date: SchedulerTimeType,
    interval: SchedulerTimeType.Stride,
    tolerance: SchedulerTimeType.Stride,
    options: SchedulerOptions?,
    _ action: @escaping () -> Void
  ) -> Cancellable {

    let id = UUID()

    func scheduleAction(_ date: SchedulerTimeType) -> () -> Void {
      return { [weak self] in
        action()
        self?.scheduled.append((id, date, scheduleAction(date.advanced(by: interval))))
      }
    }

    self.scheduled.append((id, date, scheduleAction(date.advanced(by: interval))))

    return AnyCancellable { [weak self] in
      self?.scheduled.removeAll(where: { $0.id == id })
    }
  }

  public func schedule(
    after date: SchedulerTimeType,
    tolerance: SchedulerTimeType.Stride,
    options: SchedulerOptions?,
    _ action: @escaping () -> Void
  ) {
    self.scheduled.append((UUID(), date, action))
  }

  public func schedule(options: SchedulerOptions?, _ action: @escaping () -> Void) {
    self.scheduled.append((UUID(), self.now, action))
  }
}

extension Scheduler
where
  SchedulerTimeType == DispatchQueue.SchedulerTimeType,
  SchedulerOptions == DispatchQueue.SchedulerOptions
{
  /// A test scheduler of dispatch queues.
  public static var testScheduler: TestSchedulerOf<Self> {
    // NB: `DispatchTime(uptimeNanoseconds: 0) == .now())`. Use `1` for consistency.
    TestScheduler(now: SchedulerTimeType(DispatchTime(uptimeNanoseconds: 1)))
  }
}

extension Scheduler
where
  SchedulerTimeType == RunLoop.SchedulerTimeType,
  SchedulerOptions == RunLoop.SchedulerOptions
{
  /// A test scheduler of run loops.
  public static var testScheduler: TestSchedulerOf<Self> {
    TestScheduler(now: SchedulerTimeType(Date(timeIntervalSince1970: 0)))
  }
}

extension Scheduler
where
  SchedulerTimeType == OperationQueue.SchedulerTimeType,
  SchedulerOptions == OperationQueue.SchedulerOptions
{
  /// A test scheduler of operation queues.
  public static var testScheduler: TestSchedulerOf<Self> {
    TestScheduler(now: SchedulerTimeType(Date(timeIntervalSince1970: 0)))
  }
}

/// A convenience type to specify a `TestScheduler` by the scheduler it wraps rather than by the
/// time type and options type.
public typealias TestSchedulerOf<Scheduler> = TestScheduler<
  Scheduler.SchedulerTimeType, Scheduler.SchedulerOptions
> where Scheduler: Combine.Scheduler
