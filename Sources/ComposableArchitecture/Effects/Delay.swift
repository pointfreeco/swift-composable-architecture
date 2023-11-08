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
}
