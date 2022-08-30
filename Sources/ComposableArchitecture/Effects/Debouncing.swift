import Combine

extension Effect {
  /// Turns an effect into one that can be debounced.
  ///
  /// To turn an effect into a debounce-able one you must provide an identifier, which is used to
  /// determine which in-flight effect should be canceled in order to start a new effect. Any
  /// hashable value can be used for the identifier, such as a string, but you can add a bit of
  /// protection against typos by defining a new type that conforms to `Hashable`, such as an empty
  /// struct:
  ///
  /// ```swift
  /// case let .textChanged(text):
  ///   enum SearchID {}
  ///
  ///   return environment.search(text)
  ///     .debounce(id: SearchID.self, for: 0.5, scheduler: environment.mainQueue)
  ///     .map(Action.searchResponse)
  /// ```
  ///
  /// - Parameters:
  ///   - id: The effect's identifier.
  ///   - dueTime: The duration you want to debounce for.
  ///   - scheduler: The scheduler you want to deliver the debounced output to.
  ///   - options: Scheduler options that customize the effect's delivery of elements.
  /// - Returns: An effect that publishes events only after a specified time elapses.
  public func debounce<S: Scheduler>(
    id: AnyHashable,
    for dueTime: S.SchedulerTimeType.Stride,
    scheduler: S,
    options: S.SchedulerOptions? = nil
  ) -> Self {
    switch self.operation {
    case .none:
      return .none
    case let .publisher(publisher):
      return Self(
        operation: .publisher(
          Just(())
            .setFailureType(to: Failure.self)
            .delay(for: dueTime, scheduler: scheduler, options: options)
            .flatMap { publisher.receive(on: scheduler) }
            .eraseToAnyPublisher()
        )
      )
      .cancellable(id: id, cancelInFlight: true)
    case let .run(priority, operation):
      return Self(
        operation: .run(priority) { send in
          await withTaskCancellation(id: id, cancelInFlight: true) {
            do {
              try await scheduler.sleep(for: dueTime, options: options)
              await operation(send)
            } catch {}
          }
        }
      )
    }
  }

  /// Turns an effect into one that can be debounced.
  ///
  /// A convenience for calling ``Effect/debounce(id:for:scheduler:options:)-76yye`` with a static
  /// type as the effect's unique identifier.
  ///
  /// - Parameters:
  ///   - id: A unique type identifying the effect.
  ///   - dueTime: The duration you want to debounce for.
  ///   - scheduler: The scheduler you want to deliver the debounced output to.
  ///   - options: Scheduler options that customize the effect's delivery of elements.
  /// - Returns: An effect that publishes events only after a specified time elapses.
  public func debounce<S: Scheduler>(
    id: Any.Type,
    for dueTime: S.SchedulerTimeType.Stride,
    scheduler: S,
    options: S.SchedulerOptions? = nil
  ) -> Self {
    self.debounce(id: ObjectIdentifier(id), for: dueTime, scheduler: scheduler, options: options)
  }
}
