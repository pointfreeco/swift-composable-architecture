import Dispatch
import RxSwift

extension Effect {
  /// Turns an effect into one that can be debounced.
  ///
  /// To turn an effect into a debounce-able one you must provide an identifier, which is used to
  /// determine which in-flight effect should be canceled in order to start a new effect. Any
  /// hashable value can be used for the identifier, such as a string, but you can add a bit of
  /// protection against typos by defining a new type that conforms to `Hashable`, such as an empty
  /// struct:
  ///
  ///     case let .textChanged(text):
  ///       struct SearchId: Hashable {}
  ///
  ///       return environment.search(text)
  ///         .map(Action.searchResponse)
  ///         .debounce(id: SearchId(), for: 0.5, scheduler: environment.mainQueue)
  ///
  /// - Parameters:
  ///   - id: The effect's identifier.
  ///   - dueTime: The duration you want to debounce for.
  ///   - scheduler: The scheduler you want to deliver the debounced output to.
  ///   - options: Scheduler options that customize the effect's delivery of elements.
  /// - Returns: An effect that publishes events only after a specified time elapses.
  public func debounce(
    id: AnyHashable,
    for dueTime: RxTimeInterval,
    scheduler: SchedulerType
  ) -> Effect {
    Observable.just(())
      .delay(dueTime, scheduler: scheduler)
      .flatMap { self }
      .eraseToEffect()
      .cancellable(id: id, cancelInFlight: true)
  }
}
