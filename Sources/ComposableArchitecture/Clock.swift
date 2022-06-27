


public struct AnyClock<Instant: InstantProtocol>: Clock where Instant.Duration == Duration {
  var _now: @Sendable () -> Instant
  var _minimumResolution: @Sendable () -> Duration
  var _sleep: @Sendable (Instant, Duration?) async throws -> Void

  public init<C: Clock>(clock: C) where C.Instant == Instant {
    self._now = { clock.now }
    self._minimumResolution = { clock.minimumResolution }
    self._sleep = { try await clock.sleep(until: $0, tolerance: $1) }
  }

  public var now: Instant {
    self._now()
  }
  public var minimumResolution: Instant.Duration {
    self._minimumResolution()
  }
  public func sleep(until deadline: Instant, tolerance: Instant.Duration? = nil) async throws {
    try await self._sleep(deadline, tolerance)
  }
}

public typealias AnyClockOf<C: Clock> = AnyClock<C.Instant> where C.Instant.Duration == Duration

extension AnyClock where Instant == SuspendingClock.Instant {
  public static var suspending: Self {
    .init(clock: SuspendingClock())
  }
}

public final class TestClock<Instant: InstantProtocol>: Clock, @unchecked Sendable
where
  Instant.Duration == Duration
{
  public var minimumResolution: Duration = .zero

  struct WakeUp {
    var when: Instant
    var continuation: UnsafeContinuation<Void, Never>
  }

  public private(set) var now: Instant
  public init(now: Instant) {
    self.now = now
  }

  // General storage for the sleep points we want to wake-up for
  // this could be optimized to be a more efficient data structure
  // as well as enforced for generation stability for ordering
  var wakeUps = [WakeUp]()

  // adjusting now or the wake-ups can be done from different threads/tasks
  // so they need to be treated as critical mutations
  let lock = os_unfair_lock_t.allocate(capacity: 1)

  deinit {
    lock.deallocate()
  }

  public func sleep(until deadline: Instant, tolerance: Duration? = nil) async throws {
    // Enqueue a pending wake-up into the list such that when
    return await withUnsafeContinuation {
      if deadline <= now {
        $0.resume()
      } else {
        //        os_unfair_lock_lock(lock)
        wakeUps.append(WakeUp(when: deadline, continuation: $0))
        //        os_unfair_lock_unlock(lock)
      }
    }
  }

  @MainActor
  public func advance(by amount: Duration) async {
    // step the now forward and gather all of the pending
    // wake-ups that are in need of execution
    //    os_unfair_lock_lock(lock)
    let finalDate = self.now.advanced(by: amount)
    while self.now <= finalDate {
      await Task.megaYield()
      self.wakeUps.sort { lhs, rhs in lhs.when < rhs.when }

      guard
        let nextDate = self.wakeUps.first?.when,
        finalDate >= nextDate
      else {
        self.now = finalDate
        return
      }

      self.now = nextDate

      while let wakeUp = self.wakeUps.first, wakeUp.when == nextDate {
        await Task.megaYield()
        self.wakeUps.removeFirst()
        wakeUp.continuation.resume()
      }
    }
    //    os_unfair_lock_unlock(lock)


    //    // ---
    //    now = now.advanced(by: amount)
    //    var toService = [WakeUp]()
    //    for index in (0..<(wakeUps.count)).reversed() {
    //      let wakeUp = wakeUps[index]
    //      if wakeUp.when <= now {
    //        toService.insert(wakeUp, at: 0)
    //        wakeUps.remove(at: index)
    //      }
    //    }
    //    os_unfair_lock_unlock(lock)
    //
    //    // make sure to service them outside of the lock
    //    toService.sort { lhs, rhs -> Bool in lhs.when < rhs.when }
    //    for item in toService {
    //      item.continuation.resume()
    //    }
  }
}

/*
 public func advance(by stride: SchedulerTimeType.Stride = .zero) {
 let finalDate = self.now.advanced(by: stride)

 while self.now <= finalDate {
 self.scheduled.sort { ($0.date, $0.sequence) < ($1.date, $1.sequence) }

 guard
 let nextDate = self.scheduled.first?.date,
 finalDate >= nextDate
 else {
 self.now = finalDate
 return
 }

 self.now = nextDate

 while let (_, date, action) = self.scheduled.first, date == nextDate {
 self.scheduled.removeFirst()
 action()
 }
 }
 }
 */
