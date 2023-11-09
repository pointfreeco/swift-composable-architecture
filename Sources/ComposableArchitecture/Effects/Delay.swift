import Combine

extension Effect {
  /// Delay an effect.
  ///
  /// To delay an effect you must provide an identifier, which is used to
  /// determine which in-flight effect should be canceled in order to start a new effect. Any
  /// hashable value can be used for the identifier, such as a string, but you can add a bit of
  /// protection against typos by defining a new type that conforms to `Hashable`, such as an enum:
  ///
  /// - Parameters:
  ///   - id: The effect's identifier.
  ///   - dueTime: The duration you want to debounce for.
  ///   - scheduler: The scheduler you want to deliver the debounced output to.
  ///   - options: Scheduler options that customize the effect's delivery of elements.
  ///   - cancelInFlight: Determines if any in-flight effect with the same identifier should be
  ///     canceled before starting this new one.
  /// - Returns: An effect that publishes events  after a specified time.
  ///
  @available(macOS, deprecated: 13.0, message: "use delay with a clock and tolereance parameters insted (`.delay(id:for:tolerance:clock:cancelInFlight)`).")
  @available(iOS, deprecated: 16.0, message: "use delay with a clock and tolereance parameters insted (`.delay(id:for:tolerance:clock:cancelInFlight)`).")
  @available(watchOS, deprecated: 9.0, message: "use delay with a clock and tolereance parameters insted (`.delay(id:for:tolerance:clock:cancelInFlight)`).")
  @available(tvOS, deprecated: 16.0, message: "use delay with a clock and tolereance parameters insted (`.delay(id:for:tolerance:clock:cancelInFlight)`).")
  public func delay<ID: Hashable, S: Scheduler>(
    id: ID,
    for dueTime: S.SchedulerTimeType.Stride,
    scheduler: S,
    options: S.SchedulerOptions? = nil,
    cancelInFlight: Bool = false
  ) -> Self {
    switch self.operation {
    case .none:
      return .none

    case let .publisher(publisher):
      return Self(
        operation: .publisher(
          publisher
            .delay(for: dueTime, scheduler: scheduler, options: options)
            .eraseToAnyPublisher()
        )
      )
      .cancellable(id: id, cancelInFlight: cancelInFlight)

    case .run:
      return .publisher { _EffectPublisher(self) }
        .delay(id: id, for: dueTime, scheduler: scheduler, options: options)
    }
  }

  /// Delay an effect. using async.
  ///
  /// - Parameters:
  ///   - id: The effect's identifier.
  ///   - duration: The duration you want to debounce for.
  ///   - tolerance: The tolarence you want accept.
  ///   - clock: Th clock you want to use for delaying/
  ///   - cancelInFlight: Determines if any in-flight effect with the same identifier should be
  ///     canceled before starting this new one.
  /// - Returns: An effect that publishes events  after a specified time.
  ///
  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  public func delay<ID: Hashable, C: Clock<Duration>>(
    id: ID,
    for duration: C.Instant.Duration,
    tolerance: C.Instant.Duration? = nil,
    clock: C,
    cancelInFlight: Bool = false
  ) -> Self {
    switch self.operation {
    case .none:
      return .none

    case let .publisher(publisher):
      return Self(
        operation: .run { send in
          for await action in publisher.values {
            _ = try? await clock.sleep(for: duration, tolerance: tolerance)
            await send(action)
          }
        }
      )
      .cancellable(id: id, cancelInFlight: cancelInFlight)

    case let .run(priority, operation):
      return Self(
        operation: .run(priority) { send in
          _ = try? await clock.sleep(for: duration, tolerance: tolerance)
          await operation(send)
        }
      )
      .cancellable(id: id, cancelInFlight: cancelInFlight)
    }
  }
}
