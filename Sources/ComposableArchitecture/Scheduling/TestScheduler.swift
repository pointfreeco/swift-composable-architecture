import Combine
import Foundation

/// A scheduler whose current time and execution can be controlled in a deterministic manner.
public final class TestScheduler<SchedulerTimeType, SchedulerOptions>: Scheduler
where SchedulerTimeType: Strideable, SchedulerTimeType.Stride: SchedulerTimeIntervalConvertible {

  private var lastId: UInt = 0
  public let minimumTolerance: SchedulerTimeType.Stride = .zero
  public private(set) var now: SchedulerTimeType
  private var scheduled: [(id: UInt, date: SchedulerTimeType, action: () -> Void)] = []

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
    self.scheduled.sort { ($0.date, $0.id) < ($1.date, $1.id) }

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
    tolerance _: SchedulerTimeType.Stride,
    options _: SchedulerOptions?,
    _ action: @escaping () -> Void
  ) -> Cancellable {
    let id = self.nextId()

    func scheduleAction(for date: SchedulerTimeType) -> () -> Void {
      return { [weak self] in
        action()
        let nextDate = date.advanced(by: interval)
        self?.scheduled.append((id, nextDate, scheduleAction(for: nextDate)))
      }
    }

    self.scheduled.append((id, date, scheduleAction(for: date)))

    return AnyCancellable { [weak self] in
      self?.scheduled.removeAll(where: { $0.id == id })
    }
  }

  public func schedule(
    after date: SchedulerTimeType,
    tolerance _: SchedulerTimeType.Stride,
    options _: SchedulerOptions?,
    _ action: @escaping () -> Void
  ) {
    self.scheduled.append((self.nextId(), date, action))
  }

  public func schedule(options _: SchedulerOptions?, _ action: @escaping () -> Void) {
    self.scheduled.append((self.nextId(), self.now, action))
  }

  private func nextId() -> UInt {
    self.lastId += 1
    return self.lastId
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
