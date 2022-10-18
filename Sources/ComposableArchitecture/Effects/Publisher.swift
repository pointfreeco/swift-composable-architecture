import Combine

@available(iOS, deprecated: 9999.0)
@available(macOS, deprecated: 9999.0)
@available(tvOS, deprecated: 9999.0)
@available(watchOS, deprecated: 9999.0)
extension EffectPublisher: Publisher {
  public typealias Output = Action

  public func receive<S: Combine.Subscriber>(
    subscriber: S
  ) where S.Input == Action, S.Failure == Failure {
    self.publisher.subscribe(subscriber)
  }

  var publisher: AnyPublisher<Action, Failure> {
    switch self.operation {
    case .none:
      return Empty().eraseToAnyPublisher()
    case let .publisher(publisher):
      return publisher
    case let .run(priority, operation):
      return .create { subscriber in
        let task = Task(priority: priority) { @MainActor in
          defer { subscriber.send(completion: .finished) }
          let send = Send { subscriber.send($0) }
          await operation(send)
        }
        return AnyCancellable {
          task.cancel()
        }
      }
    }
  }
}

extension EffectPublisher {
  /// Initializes an effect that wraps a publisher.
  ///
  /// > Important: This Combine interface has been soft-deprecated in favor of Swift concurrency.
  /// > Prefer performing asynchronous work directly in
  /// > ``EffectPublisher/run(priority:operation:catch:file:fileID:line:)`` by adopting a
  /// > non-Combine interface, or by iterating over the publisher's asynchronous sequence of
  /// > `values`:
  /// >
  /// > ```swift
  /// > return .run { send in
  /// >   for await value in publisher.values {
  /// >     send(.response(value))
  /// >   }
  /// > }
  /// > ```
  ///
  /// - Parameter publisher: A publisher.
  @available(
    iOS, deprecated: 9999.0,
    message: "Iterate over 'Publisher.values' in an 'EffectTask.run', instead."
  )
  @available(
    macOS, deprecated: 9999.0,
    message: "Iterate over 'Publisher.values' in an 'EffectTask.run', instead."
  )
  @available(
    tvOS, deprecated: 9999.0,
    message: "Iterate over 'Publisher.values' in an 'EffectTask.run', instead."
  )
  @available(
    watchOS, deprecated: 9999.0,
    message: "Iterate over 'Publisher.values' in an 'EffectTask.run', instead."
  )
  public init<P: Publisher>(_ publisher: P) where P.Output == Output, P.Failure == Failure {
    self.operation = .publisher(publisher.eraseToAnyPublisher())
  }

  /// Initializes an effect that immediately emits the value passed in.
  ///
  /// - Parameter value: The value that is immediately emitted by the effect.
  @available(iOS, deprecated: 9999.0, message: "Wrap the value in 'EffectTask.task', instead.")
  @available(macOS, deprecated: 9999.0, message: "Wrap the value in 'EffectTask.task', instead.")
  @available(tvOS, deprecated: 9999.0, message: "Wrap the value in 'EffectTask.task', instead.")
  @available(watchOS, deprecated: 9999.0, message: "Wrap the value in 'EffectTask.task', instead.")
  public init(value: Action) {
    self.init(Just(value).setFailureType(to: Failure.self))
  }

  /// Initializes an effect that immediately fails with the error passed in.
  ///
  /// - Parameter error: The error that is immediately emitted by the effect.
  @available(
    iOS, deprecated: 9999.0,
    message: "Throw and catch errors directly in 'EffectTask.task' and 'EffectTask.run', instead."
  )
  @available(
    macOS, deprecated: 9999.0,
    message: "Throw and catch errors directly in 'EffectTask.task' and 'EffectTask.run', instead."
  )
  @available(
    tvOS, deprecated: 9999.0,
    message: "Throw and catch errors directly in 'EffectTask.task' and 'EffectTask.run', instead."
  )
  @available(
    watchOS, deprecated: 9999.0,
    message: "Throw and catch errors directly in 'EffectTask.task' and 'EffectTask.run', instead."
  )
  public init(error: Failure) {
    // NB: Ideally we'd return a `Fail` publisher here, but due to a bug in iOS 13 that publisher
    //     can crash when used with certain combinations of operators such as `.retry.catch`. The
    //     bug was fixed in iOS 14, but to remain compatible with iOS 13 and higher we need to do
    //     a little trickery to fail in a slightly different way.
    self.init(
      Deferred {
        Future { $0(.failure(error)) }
      }
    )
  }

  /// Creates an effect that can supply a single value asynchronously in the future.
  ///
  /// This can be helpful for converting APIs that are callback-based into ones that deal with
  /// ``EffectPublisher``s.
  ///
  /// For example, to create an effect that delivers an integer after waiting a second:
  ///
  /// ```swift
  /// EffectPublisher<Int, Never>.future { callback in
  ///   DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
  ///     callback(.success(42))
  ///   }
  /// }
  /// ```
  ///
  /// Note that you can only deliver a single value to the `callback`. If you send more they will be
  /// discarded:
  ///
  /// ```swift
  /// EffectPublisher<Int, Never>.future { callback in
  ///   DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
  ///     callback(.success(42))
  ///     callback(.success(1729)) // Will not be emitted by the effect
  ///   }
  /// }
  /// ```
  ///
  ///  If you need to deliver more than one value to the effect, you should use the
  ///  ``EffectPublisher`` initializer that accepts a ``Subscriber`` value.
  ///
  /// - Parameter attemptToFulfill: A closure that takes a `callback` as an argument which can be
  ///   used to feed it `Result<Output, Failure>` values.
  @available(iOS, deprecated: 9999.0, message: "Use 'EffectTask.task', instead.")
  @available(macOS, deprecated: 9999.0, message: "Use 'EffectTask.task', instead.")
  @available(tvOS, deprecated: 9999.0, message: "Use 'EffectTask.task', instead.")
  @available(watchOS, deprecated: 9999.0, message: "Use 'EffectTask.task', instead.")
  public static func future(
    _ attemptToFulfill: @escaping (@escaping (Result<Action, Failure>) -> Void) -> Void
  ) -> Self {
    let dependencies = DependencyValues._current
    return Deferred {
      DependencyValues.$_current.withValue(dependencies) {
        Future(attemptToFulfill)
      }
    }.eraseToEffect()
  }

  /// Initializes an effect that lazily executes some work in the real world and synchronously sends
  /// that data back into the store.
  ///
  /// For example, to load a user from some JSON on the disk, one can wrap that work in an effect:
  ///
  /// ```swift
  /// EffectPublisher<User, Error>.result {
  ///   let fileUrl = URL(
  ///     fileURLWithPath: NSSearchPathForDirectoriesInDomains(
  ///       .documentDirectory, .userDomainMask, true
  ///     )[0]
  ///   )
  ///   .appendingPathComponent("user.json")
  ///
  ///   let result = Result<User, Error> {
  ///     let data = try Data(contentsOf: fileUrl)
  ///     return try JSONDecoder().decode(User.self, from: $0)
  ///   }
  ///
  ///   return result
  /// }
  /// ```
  ///
  /// - Parameter attemptToFulfill: A closure encapsulating some work to execute in the real world.
  /// - Returns: An effect.
  @available(iOS, deprecated: 9999.0, message: "Use 'EffectTask.task', instead.")
  @available(macOS, deprecated: 9999.0, message: "Use 'EffectTask.task', instead.")
  @available(tvOS, deprecated: 9999.0, message: "Use 'EffectTask.task', instead.")
  @available(watchOS, deprecated: 9999.0, message: "Use 'EffectTask.task', instead.")
  public static func result(_ attemptToFulfill: @escaping () -> Result<Action, Failure>) -> Self {
    .future { $0(attemptToFulfill()) }
  }

  /// Initializes an effect from a callback that can send as many values as it wants, and can send
  /// a completion.
  ///
  /// This initializer is useful for bridging callback APIs, delegate APIs, and manager APIs to the
  /// ``EffectPublisher`` type. One can wrap those APIs in an Effect so that its events are sent
  /// through the effect, which allows the reducer to handle them.
  ///
  /// For example, one can create an effect to ask for access to `MPMediaLibrary`. It can start by
  /// sending the current status immediately, and then if the current status is `notDetermined` it
  /// can request authorization, and once a status is received it can send that back to the effect:
  ///
  /// ```swift
  /// EffectPublisher.run { subscriber in
  ///   subscriber.send(MPMediaLibrary.authorizationStatus())
  ///
  ///   guard MPMediaLibrary.authorizationStatus() == .notDetermined else {
  ///     subscriber.send(completion: .finished)
  ///     return AnyCancellable {}
  ///   }
  ///
  ///   MPMediaLibrary.requestAuthorization { status in
  ///     subscriber.send(status)
  ///     subscriber.send(completion: .finished)
  ///   }
  ///   return AnyCancellable {
  ///     // Typically clean up resources that were created here, but this effect doesn't
  ///     // have any.
  ///   }
  /// }
  /// ```
  ///
  /// - Parameter work: A closure that accepts a ``Subscriber`` value and returns a cancellable.
  ///   When the ``EffectPublisher`` is completed, the cancellable will be used to clean up any
  ///   resources created when the effect was started.
  @available(
    iOS, deprecated: 9999.0, message: "Use the async version of 'EffectTask.run', instead."
  )
  @available(
    macOS, deprecated: 9999.0, message: "Use the async version of 'EffectTask.run', instead."
  )
  @available(
    tvOS, deprecated: 9999.0, message: "Use the async version of 'EffectTask.run', instead."
  )
  @available(
    watchOS, deprecated: 9999.0, message: "Use the async version of 'Effect.run', instead."
  )
  public static func run(
    _ work: @escaping (EffectPublisher.Subscriber) -> Cancellable
  ) -> Self {
    let dependencies = DependencyValues._current
    return AnyPublisher.create { subscriber in
      DependencyValues.$_current.withValue(dependencies) {
        work(subscriber)
      }
    }
    .eraseToEffect()
  }

  /// Creates an effect that executes some work in the real world that doesn't need to feed data
  /// back into the store. If an error is thrown, the effect will complete and the error will be
  /// ignored.
  ///
  /// - Parameter work: A closure encapsulating some work to execute in the real world.
  /// - Returns: An effect.
  @available(iOS, deprecated: 9999.0, message: "Use the async version, instead.")
  @available(macOS, deprecated: 9999.0, message: "Use the async version, instead.")
  @available(tvOS, deprecated: 9999.0, message: "Use the async version, instead.")
  @available(watchOS, deprecated: 9999.0, message: "Use the async version, instead.")
  public static func fireAndForget(_ work: @escaping () throws -> Void) -> Self {
    // NB: Ideally we'd return a `Deferred` wrapping an `Empty(completeImmediately: true)`, but
    //     due to a bug in iOS 13.2 that publisher will never complete. The bug was fixed in
    //     iOS 13.3, but to remain compatible with iOS 13.2 and higher we need to do a little
    //     trickery to make sure the deferred publisher completes.
    let dependencies = DependencyValues._current
    return Deferred { () -> Publishers.CompactMap<Result<Action?, Failure>.Publisher, Action> in
      DependencyValues.$_current.withValue(dependencies) {
        try? work()
      }
      return Just<Output?>(nil)
        .setFailureType(to: Failure.self)
        .compactMap { $0 }
    }
    .eraseToEffect()
  }
}

extension EffectPublisher where Failure == Error {
  /// Initializes an effect that lazily executes some work in the real world and synchronously sends
  /// that data back into the store.
  ///
  /// For example, to load a user from some JSON on the disk, one can wrap that work in an effect:
  ///
  /// ```swift
  /// EffectPublisher<User, Error>.catching {
  ///   let fileUrl = URL(
  ///     fileURLWithPath: NSSearchPathForDirectoriesInDomains(
  ///       .documentDirectory, .userDomainMask, true
  ///     )[0]
  ///   )
  ///   .appendingPathComponent("user.json")
  ///
  ///   let data = try Data(contentsOf: fileUrl)
  ///   return try JSONDecoder().decode(User.self, from: $0)
  /// }
  /// ```
  ///
  /// - Parameter work: A closure encapsulating some work to execute in the real world.
  /// - Returns: An effect.
  @available(
    iOS, deprecated: 9999.0,
    message: "Throw and catch errors directly in 'EffectTask.task' and 'EffectTask.run', instead."
  )
  @available(
    macOS, deprecated: 9999.0,
    message: "Throw and catch errors directly in 'EffectTask.task' and 'EffectTask.run', instead."
  )
  @available(
    tvOS, deprecated: 9999.0,
    message: "Throw and catch errors directly in 'EffectTask.task' and 'EffectTask.run', instead."
  )
  @available(
    watchOS, deprecated: 9999.0,
    message: "Throw and catch errors directly in 'EffectTask.task' and 'EffectTask.run', instead."
  )
  public static func catching(_ work: @escaping () throws -> Action) -> Self {
    .future { $0(Result { try work() }) }
  }
}

extension Publisher {
  /// Turns any publisher into an ``EffectPublisher``.
  ///
  /// This can be useful for when you perform a chain of publisher transformations in a reducer, and
  /// you need to convert that publisher to an effect so that you can return it from the reducer:
  ///
  /// ```swift
  /// case .buttonTapped:
  ///   return fetchUser(id: 1)
  ///     .filter(\.isAdmin)
  ///     .eraseToEffect()
  /// ```
  ///
  /// - Returns: An effect that wraps `self`.
  @available(
    iOS, deprecated: 9999.0,
    message: "Iterate over 'Publisher.values' in an 'EffectTask.run', instead."
  )
  @available(
    macOS, deprecated: 9999.0,
    message: "Iterate over 'Publisher.values' in an 'EffectTask.run', instead."
  )
  @available(
    tvOS, deprecated: 9999.0,
    message: "Iterate over 'Publisher.values' in an 'EffectTask.run', instead."
  )
  @available(
    watchOS, deprecated: 9999.0,
    message: "Iterate over 'Publisher.values' in an 'EffectTask.run', instead."
  )
  public func eraseToEffect() -> EffectPublisher<Output, Failure> {
    EffectPublisher(self)
  }

  /// Turns any publisher into an ``EffectPublisher``.
  ///
  /// This is a convenience operator for writing ``EffectPublisher/eraseToEffect()`` followed by
  /// ``EffectPublisher/map(_:)-28ghh`.
  ///
  /// ```swift
  /// case .buttonTapped:
  ///   return fetchUser(id: 1)
  ///     .filter(\.isAdmin)
  ///     .eraseToEffect(ProfileAction.adminUserFetched)
  /// ```
  ///
  /// - Parameters:
  ///   - transform: A mapping function that converts `Output` to another type.
  /// - Returns: An effect that wraps `self` after mapping `Output` values.
  @available(
    iOS, deprecated: 9999.0,
    message: "Iterate over 'Publisher.values' in an 'EffectTask.run', instead."
  )
  @available(
    macOS, deprecated: 9999.0,
    message: "Iterate over 'Publisher.values' in an 'EffectTask.run', instead."
  )
  @available(
    tvOS, deprecated: 9999.0,
    message: "Iterate over 'Publisher.values' in an 'EffectTask.run', instead."
  )
  @available(
    watchOS, deprecated: 9999.0,
    message: "Iterate over 'Publisher.values' in an 'EffectTask.run', instead."
  )
  public func eraseToEffect<T>(
    _ transform: @escaping (Output) -> T
  ) -> EffectPublisher<T, Failure> {
    self.map(transform)
      .eraseToEffect()
  }

  /// Turns any publisher into an ``EffectTask`` that cannot fail by wrapping its output and failure
  /// in a result.
  ///
  /// This can be useful when you are working with a failing API but want to deliver its data to an
  /// action that handles both success and failure.
  ///
  /// ```swift
  /// case .buttonTapped:
  ///   return self.apiClient.fetchUser(id: 1)
  ///     .catchToEffect()
  ///     .map(ProfileAction.userResponse)
  /// ```
  ///
  /// - Returns: An effect that wraps `self`.
  @available(
    iOS, deprecated: 9999.0,
    message: "Iterate over 'Publisher.values' in an 'EffectTask.run', instead."
  )
  @available(
    macOS, deprecated: 9999.0,
    message: "Iterate over 'Publisher.values' in an 'EffectTask.run', instead."
  )
  @available(
    tvOS, deprecated: 9999.0,
    message: "Iterate over 'Publisher.values' in an 'EffectTask.run', instead."
  )
  @available(
    watchOS, deprecated: 9999.0,
    message: "Iterate over 'Publisher.values' in an 'EffectTask.run', instead."
  )
  public func catchToEffect() -> EffectTask<Result<Output, Failure>> {
    self.catchToEffect { $0 }
  }

  /// Turns any publisher into an ``EffectTask`` that cannot fail by wrapping its output and failure
  /// into a result and then applying passed in function to it.
  ///
  /// This is a convenience operator for writing ``EffectPublisher/eraseToEffect()`` followed by
  /// ``EffectPublisher/map(_:)-28ghh`.
  ///
  /// ```swift
  /// case .buttonTapped:
  ///   return self.apiClient.fetchUser(id: 1)
  ///     .catchToEffect(ProfileAction.userResponse)
  /// ```
  ///
  /// - Parameters:
  ///   - transform: A mapping function that converts `Result<Output,Failure>` to another type.
  /// - Returns: An effect that wraps `self`.
  @available(
    iOS, deprecated: 9999.0,
    message: "Iterate over 'Publisher.values' in an 'EffectTask.run', instead."
  )
  @available(
    macOS, deprecated: 9999.0,
    message: "Iterate over 'Publisher.values' in an 'EffectTask.run', instead."
  )
  @available(
    tvOS, deprecated: 9999.0,
    message: "Iterate over 'Publisher.values' in an 'EffectTask.run', instead."
  )
  @available(
    watchOS, deprecated: 9999.0,
    message: "Iterate over 'Publisher.values' in an 'EffectTask.run', instead."
  )
  public func catchToEffect<T>(
    _ transform: @escaping (Result<Output, Failure>) -> T
  ) -> EffectTask<T> {
    let dependencies = DependencyValues._current
    let transform = { action in
      DependencyValues.$_current.withValue(dependencies) {
        transform(action)
      }
    }
    return
      self
      .map { transform(.success($0)) }
      .catch { Just(transform(.failure($0))) }
      .eraseToEffect()
  }

  /// Turns any publisher into an ``EffectPublisher`` for any output and failure type by ignoring
  /// all output and any failure.
  ///
  /// This is useful for times you want to fire off an effect but don't want to feed any data back
  /// into the system. It can automatically promote an effect to your reducer's domain.
  ///
  /// ```swift
  /// case .buttonTapped:
  ///   return analyticsClient.track("Button Tapped")
  ///     .fireAndForget()
  /// ```
  ///
  /// - Parameters:
  ///   - outputType: An output type.
  ///   - failureType: A failure type.
  /// - Returns: An effect that never produces output or errors.
  @available(
    iOS, deprecated: 9999.0,
    message:
      "Iterate over 'Publisher.values' in the static version of 'Effect.fireAndForget', instead."
  )
  @available(
    macOS, deprecated: 9999.0,
    message:
      "Iterate over 'Publisher.values' in the static version of 'Effect.fireAndForget', instead."
  )
  @available(
    tvOS, deprecated: 9999.0,
    message:
      "Iterate over 'Publisher.values' in the static version of 'Effect.fireAndForget', instead."
  )
  @available(
    watchOS, deprecated: 9999.0,
    message:
      "Iterate over 'Publisher.values' in the static version of 'Effect.fireAndForget', instead."
  )
  public func fireAndForget<NewOutput, NewFailure>(
    outputType: NewOutput.Type = NewOutput.self,
    failureType: NewFailure.Type = NewFailure.self
  ) -> EffectPublisher<NewOutput, NewFailure> {
    return
      self
      .flatMap { _ in Empty<NewOutput, Failure>() }
      .catch { _ in Empty() }
      .eraseToEffect()
  }
}
