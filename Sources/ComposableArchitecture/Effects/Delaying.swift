import Combine

extension Effect {
    /// Returns an effect that will be executed after given `dueTime`.
    ///
    /// To create a delayed effect, you must provide an identifier, which is used to
    /// identify which in-flight effect should be canceled. Any hashable
    /// value can be used for the identifier, such as a string, but you can add a bit of protection
    /// against typos by defining a new type that conforms to `Hashable`, such as an empty struct:
    ///
    ///
    ///     case let .locationTapped(location)
    ///       struct SearchWeatherId: Hashable {}
    ///
    ///       return Effect.delay(
    ///         environment.weatherClient
    ///            .weather(location.id)
    ///            .receive(on: environment.mainQueue)
    ///            .catchToEffect()
    ///            .map(SearchAction.locationWeatherResponse)
    ///         id: SearchWeatherId(),
    ///         for: 3,
    ///         scheduller: environment.mainQueue
    ///       )
    ///
    /// - Parameters:
    ///   - upstream: the effect you want to delay.
    ///   - id: The effect's identifier.
    ///   - dueTime: The duration you want to debounce for.
    ///   - scheduler: The scheduler you want to deliver the debounced output to.
    ///   - options: Scheduler options that customize the effect's delivery of elements.
    /// - Returns: An effect that will be executed after `dueTime`
    public static func delay<S: Scheduler>(
        _ upstream: Effect,
        id: AnyHashable,
        for dueTime: S.SchedulerTimeType.Stride,
        scheduler: S,
        options: S.SchedulerOptions? = nil
    ) -> Effect {
        Just(())
            .setFailureType(to: Failure.self)
            .delay(for: dueTime, scheduler: scheduler, options: options)
            .flatMap { _ in
                upstream
            }
            .eraseToEffect()
            .cancellable(id: id)
    }
}

