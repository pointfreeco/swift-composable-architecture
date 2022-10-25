#if swift(>=5.7) && (canImport(RegexBuilder) || !os(macOS) && !targetEnvironment(macCatalyst))
  import Clocks

  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  extension DependencyValues {
    public var continuousClock: any Clock<Duration> {
      get { self[ContinuousClockKey.self] }
      set { self[ContinuousClockKey.self] = newValue }
    }
    public var suspendingClock: any Clock<Duration> {
      get { self[SuspendingClockKey.self] }
      set { self[SuspendingClockKey.self] = newValue }
    }

    private enum ContinuousClockKey: DependencyKey {
      static let liveValue: any Clock<Duration> = ContinuousClock()
      static let testValue: any Clock<Duration> = UnimplementedClock(name: "ContinuousClock")
    }
    private enum SuspendingClockKey: DependencyKey {
      static let liveValue: any Clock<Duration> = SuspendingClock()
      static let testValue: any Clock<Duration> = UnimplementedClock(name: "SuspendingClock")
    }
  }
#endif
