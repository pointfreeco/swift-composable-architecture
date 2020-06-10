import RxSwift
import Foundation

/// The `Effect` type encapsulates a unit of work that can be run in the outside world, and can feed
/// data back to the `Store`. It is the perfect place to do side effects, such as network requests,
/// saving/loading from disk, creating timers, interacting with dependencies, and more.
///
/// Effects are returned from reducers so that the `Store` can perform the effects after the reducer
/// is done running. It is important to note that `Store` is not thread safe, and so all effects
/// must receive values on the same thread, **and** if the store is being used to drive UI then it
/// must receive values on the main thread.
///
/// An effect simply wraps a `Publisher` value and provides some convenience initializers for
/// constructing some common types of effects.
public struct Effect<Output>: ObservableType {
  public typealias Element = Output

  public let upstream: Observable<Output>

  /// Initializes an effect that wraps a publisher. Each emission of the wrapped publisher will be
  /// emitted by the effect.
  ///
  /// This initializer is useful for turning any publisher into an effect. For example:
  ///
  ///     Effect(
  ///       NotificationCenter.default
  ///         .publisher(for: UIApplication.userDidTakeScreenshotNotification)
  ///     )
  ///
  /// Alternatively, you can use the `.eraseToEffect()` method that is defined on the `Publisher`
  /// protocol:
  ///
  ///     NotificationCenter.default
  ///       .publisher(for: UIApplication.userDidTakeScreenshotNotification)
  ///       .eraseToEffect()
  ///
  /// - Parameter publisher: A publisher.
  public init(_ observable: Observable<Output>) {
    self.upstream = observable
  }

  public func subscribe<Observer>(
      _ observer: Observer
  ) -> Disposable where Observer: ObserverType, Element == Observer.Element {
    upstream.subscribe(observer)
  }

  /// Initializes an effect that immediately emits the value passed in.
  ///
  /// - Parameter value: The value that is immediately emitted by the effect.
  public init(value: Output) {
    self.init(Observable.just(value))
  }

  /// Initializes an effect that immediately fails with the error passed in.
  ///
  /// - Parameter error: The error that is immediately emitted by the effect.
  public init(error: Error) {
    self.init(Observable.error(error))
  }

  /// An effect that does nothing and completes immediately. Useful for situations where you must
  /// return an effect, but you don't need to do anything.
  public static var none: Effect {
    Observable.empty().eraseToEffect()
  }

  /// Creates an effect that can supply a single value asynchronously in the future.
  ///
  /// This can be helpful for converting APIs that are callback-based into ones that deal with
  /// `Effect`s.
  ///
  /// For example, to create an effect that delivers an integer after waiting a second:
  ///
  ///     Effect<Int, Never>.future { callback in
  ///       DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
  ///         callback(.success(42))
  ///       }
  ///     }
  ///
  /// Note that you can only deliver a single value to the `callback`. If you send more they will be
  /// discarded:
  ///
  ///     Effect<Int, Never>.future { callback in
  ///       DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
  ///         callback(.success(42))
  ///         callback(.success(1729)) // Will not be emitted by the effect
  ///       }
  ///     }
  ///
  ///  If you need to deliver more than one value to the effect, you should use the `Effect`
  ///  initializer that accepts a `Subscriber` value.
  ///
  /// - Parameter attemptToFulfill: A closure that takes a `callback` as an argument which can be
  ///   used to feed it `Result<Output, Failure>` values.
  public static func future(
    _ attemptToFulfill: @escaping (@escaping (Result<Output, Error>) -> Void) -> Void
  ) -> Effect {
    Observable.create { observer in
      attemptToFulfill { result in
        switch result {
        case let .success(output):
          observer.onNext(output)
          observer.onCompleted()
        case let .failure(error):
          observer.onError(error)
        }
      }

      return Disposables.create()
    }
    .eraseToEffect()
  }

  /// Initializes an effect that lazily executes some work in the real world and synchronously sends
  /// that data back into the store.
  ///
  /// For example, to load a user from some JSON on the disk, one can wrap that work in an effect:
  ///
  ///     Effect<User, Error>.result {
  ///       let fileUrl = URL(
  ///         fileURLWithPath: NSSearchPathForDirectoriesInDomains(
  ///           .documentDirectory, .userDomainMask, true
  ///         )[0]
  ///       )
  ///       .appendingPathComponent("user.json")
  ///
  ///       let result = Result<User, Error> {
  ///         let data = try Data(contentsOf: fileUrl)
  ///         return try JSONDecoder().decode(User.self, from: $0)
  ///       }
  ///
  ///       return result
  ///     }
  ///
  /// - Parameter attemptToFulfill: A closure encapsulating some work to execute in the real world.
  /// - Returns: An effect.
  public static func result(_ attemptToFulfill: @escaping () -> Result<Output, Error>) -> Self {
    Observable.create { observer in
      switch attemptToFulfill() {
      case let .success(output):
        observer.onNext(output)
        observer.onCompleted()
      case let .failure(error):
        observer.onError(error)
      }

      return Disposables.create()
    }
    .eraseToEffect()
  }

  /// Initializes an effect from a callback that can send as many values as it wants, and can send
  /// a completion.
  ///
  /// This initializer is useful for bridging callback APIs, delegate APIs, and manager APIs to the
  /// `Effect` type. One can wrap those APIs in an Effect so that its events are sent through the
  /// effect, which allows the reducer to handle them.
  ///
  /// For example, one can create an effect to ask for access to `MPMediaLibrary`. It can start by
  /// sending the current status immediately, and then if the current status is `notDetermined` it
  /// can request authorization, and once a status is received it can send that back to the effect:
  ///
  ///     Effect.run { subscriber in
  ///       subscriber.send(MPMediaLibrary.authorizationStatus())
  ///
  ///       guard MPMediaLibrary.authorizationStatus() == .notDetermined else {
  ///         subscriber.send(completion: .finished)
  ///         return AnyCancellable {}
  ///       }
  ///
  ///       MPMediaLibrary.requestAuthorization { status in
  ///         subscriber.send(status)
  ///         subscriber.send(completion: .finished)
  ///       }
  ///       return AnyCancellable {
  ///         // Typically clean up resources that were created here, but this effect doesn't
  ///         // have any.
  ///       }
  ///     }
  ///
  /// - Parameter work: A closure that accepts a `Subscriber` value and returns a cancellable. When
  ///   the `Effect` is completed, the cancellable will be used to clean up any resources created
  ///   when the effect was started.
  public static func run(
    _ work: @escaping (AnyObserver<Output>) -> Disposable
  ) -> Self {
    Observable.create(work).eraseToEffect()
  }

  /// Concatenates a variadic list of effects together into a single effect, which runs the effects
  /// one after the other.
  ///
  /// - Parameter effects: A variadic list of effects.
  /// - Returns: A new effect
  public static func concatenate(_ effects: Effect...) -> Effect {
    .concatenate(effects)
  }

  /// Concatenates a collection of effects together into a single effect, which runs the effects one
  /// after the other.
  ///
  /// - Parameter effects: A collection of effects.
  /// - Returns: A new effect
  public static func concatenate<C: Collection>(
    _ effects: C
  ) -> Effect where C.Element == Effect {
    guard let first = effects.first else { return .none }

    return
      effects
      .dropFirst()
      .reduce(into: first) { effects, effect in
        effects = effects.concat(effect).eraseToEffect()
      }
  }

  /// Merges a variadic list of effects together into a single effect, which runs the effects at the
  /// same time.
  ///
  /// - Parameter effects: A list of effects.
  /// - Returns: A new effect
  public static func merge(
    _ effects: Effect...
  ) -> Effect {
    .merge(effects)
  }

  /// Merges a sequence of effects together into a single effect, which runs the effects at the same
  /// time.
  ///
  /// - Parameter effects: A sequence of effects.
  /// - Returns: A new effect
  public static func merge<S: Sequence>(_ effects: S) -> Effect where S.Element == Effect {
    Observable
      .merge(effects.map { $0.asObservable() })
      .eraseToEffect()
  }

  /// Creates an effect that executes some work in the real world that doesn't need to feed data
  /// back into the store.
  ///
  /// - Parameter work: A closure encapsulating some work to execute in the real world.
  /// - Returns: An effect.
  public static func fireAndForget(_ work: @escaping () -> Void) -> Effect {
    return Effect(Observable.deferred {
      work()
      return Observable<Output>.empty()
    })
  }

  /// Transforms all elements from the upstream effect with a provided closure.
  ///
  /// - Parameter transform: A closure that transforms the upstream effect's output to a new output.
  /// - Returns: A publisher that uses the provided closure to map elements from the upstream effect
  ///   to new elements that it then publishes.
  public func map<T>(_ transform: @escaping (Output) -> T) -> Effect<T> {
    .init(self.map(transform))
  }
}

extension Effect where Output == Never {
  /// Upcasts an `Effect<Never, Failure>` to an `Effect<T, Failure>` for any type `T`. This is
  /// possible to do because an `Effect<Never, Failure>` can never produce any values to feed back
  /// into the store (hence the name "fire and forget"), and therefore we can act like it's an
  /// effect that produces values of any type (since it never produces values).
  ///
  /// This is useful for times you have an `Effect<Never, Failure>` but need to massage it into
  /// another type in order to return it from a reducer:
  ///
  ///     case .buttonTapped:
  ///       return analyticsClient.track("Button Tapped")
  ///         .fireAndForget()
  ///
  /// - Returns: An effect.
  public func fireAndForget<T>() -> Effect<T> {
    func absurd<A>(_ never: Never) -> A {}
    return self.map(absurd)
  }
}

extension ObservableType {
  /// Turns any publisher into an `Effect`.
  ///
  /// This can be useful for when you perform a chain of publisher transformations in a reducer, and
  /// you need to convert that publisher to an effect so that you can return it from the reducer:
  ///
  ///     case .buttonTapped:
  ///       return fetchUser(id: 1)
  ///         .filter(\.isAdmin)
  ///         .eraseToEffect()
  ///
  /// - Returns: An effect that wraps `self`.
  public func eraseToEffect() -> Effect<Element> {
    Effect(asObservable())
  }

  /// Turns any publisher into an `Effect` that cannot fail by wrapping its output and failure in a
  /// result.
  ///
  /// This can be useful when you are working with a failing API but want to deliver its data to an
  /// action that handles both success and failure.
  ///
  ///     case .buttonTapped:
  ///       return fetchUser(id: 1)
  ///         .catchToEffect()
  ///         .map(ProfileAction.userResponse)
  ///
  /// - Returns: An effect that wraps `self`.
  public func catchToEffect() -> Effect<Result<Element, Error>> {
    self.map(Result<Element, Error>.success)
      .catchError { Observable<Result<Element, Error>>.just(Result.failure($0)) }
      .eraseToEffect()
  }
}
