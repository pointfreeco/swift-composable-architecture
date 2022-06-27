public struct AnyClock: Clock {
  public struct Instant: InstantProtocol {
    var duration: Duration

    public func advanced(by duration: Duration) -> Self {
      .init(duration: self.duration + duration)
    }

    public func duration(to other: Self) -> Duration {
      other.duration - self.duration
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
      lhs.duration < rhs.duration
    }
  }

  var _now: @Sendable () -> Instant
  var _minimumResolution: @Sendable () -> Duration
  var _sleep: @Sendable (Instant, Duration?) async throws -> Void

  public init<C: Clock>(clock: C) where C.Instant.Duration == Duration {
    let start = clock.now
    self._now = { Instant(duration: start.duration(to: clock.now)) }
    self._minimumResolution = { clock.minimumResolution }
    self._sleep = { until, tolerance in
      try await clock.sleep(until: start.advanced(by: until.duration), tolerance: tolerance)
    }
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

extension AnyClock {
  public static var suspending: Self {
    .init(clock: SuspendingClock())
  }
}

public final class TestClock: Clock, @unchecked Sendable {
  public struct Instant: InstantProtocol {
    var duration: Duration

    public func advanced(by duration: Duration) -> Self {
      .init(duration: self.duration + duration)
    }

    public func duration(to other: Self) -> Duration {
      other.duration - self.duration
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
      lhs.duration < rhs.duration
    }
  }

  public var minimumResolution: Duration = .zero

  public init() {}

  struct WakeUp {
    var when: Instant
    var continuation: UnsafeContinuation<Void, Never>
  }

  public private(set) var now: Instant = .init(duration: .zero)

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
        os_unfair_lock_lock(lock)
        wakeUps.append(WakeUp(when: deadline, continuation: $0))
        os_unfair_lock_unlock(lock)
      }
    }
  }

  @MainActor
  public func advance(by amount: Duration) async {
    let finalDate = self.now.advanced(by: amount)
    while self.now <= finalDate {
      await Task.megaYield()
      os_unfair_lock_lock(lock)
      self.wakeUps.sort { lhs, rhs in lhs.when < rhs.when }

      guard
        let next = self.wakeUps.first,
        finalDate >= next.when
      else {
        self.now = finalDate
        os_unfair_lock_unlock(lock)
        return
      }

      self.now = next.when
      await Task.megaYield()
      self.wakeUps.removeFirst()
      os_unfair_lock_unlock(lock)
      next.continuation.resume()
    }
  }
}
