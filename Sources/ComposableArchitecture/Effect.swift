import Combine
import Foundation

/*

  0.22
    Backwards compat
    - introduce .stream { } helpers on Effect so that people can use async/await
    - introduce Effect.init that takes an async sequence

 1.0
   - Make Effect an AsyncSequence
   - Make store, view store and test store run off of async sequence too
   - introduce `publisher.eraseToEffect()` to convert their publishers to new Effect



 Effect.future { callback in
  callback(.success(42))
 }

 */


struct _Effect<Output, Failure: Error> {
  // TODO: use enum output | failure | completed
  let run: (@escaping (Result<Output, Failure>) -> Void) -> Void
}

#if canImport(Combine)
extension _Effect: Publisher {
  func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
    self.run { result in
      switch result {
      case let .success(output):
        // TODO: what to do here
        let demand = subscriber.receive(output)
      case let .failure(error):
        subscriber.receive(completion: .failure(error))
      }
    }
  }
}
#endif

#if canImport(_Concurrency)
extension _Effect: AsyncSequence {
  __consuming func makeAsyncIterator() -> _Iterator {
    fatalError()
  }

  typealias AsyncIterator = _Iterator
  typealias Element = Output

  struct _Iterator: AsyncIteratorProtocol {
    typealias Element = Output
    mutating func next() async throws -> Output? {
      nil
    }
  }


}
#endif


@available(iOSApplicationExtension 15.0, *)
func foo(e: _Effect<Int, Never>) {
  let tmp = e.map { await $0 }
}



extension Result where Failure == Error {
  init(_ catching: () async throws -> Success) async {
    do {
      self = .success(try await catching())
    } catch {
      self = .failure(error)
    }
  }
}




@available(iOS 15.0, *)
struct FactClient {
  var fetch: (Int) async throws -> String

  static let live = Self(
    fetch: { count in
      let (data, _) = try await URLSession.shared.data(from: .init(string: "http://numbersapi.com/42/trivia")!)
      return String.init(decoding: data, as: UTF8.self)
    }
  )
}

@available(iOS 15.0, *)
extension Effect {
  static func task(
    operation: @escaping () async -> Output
  ) -> Effect<Output, Failure>
  where Failure == Never {
    .future { callback in
      Task {
        callback(.success(await operation()))
      }
    }
  }

  static func asyncThrowing(
    operation: @escaping () async throws -> Output
  ) -> Effect<Output, Failure>
  where Failure == Error {
    .future { callback in
      Task {
        do {
          callback(.success(try await operation()))
        } catch {
          callback(.failure(error))
        }
      }
    }
  }
}

enum Action {
  case finished
  case started
  case tapped
  case response(Result<String, Error>)
}

@available(iOS 15, *)
let reducer = Reducer<String, Action, FactClient> { state, action, environment in
  switch action {
  case .finished:
    return .none
  case .started:
    return .none
  case .tapped:

    return .task {
      await .response(Result { try await environment.fetch(42) })
    }

    return .throwingStream { continuation in
      struct Foo: Error {}
      throw Foo()
    }
    .catch { Action.response(.failure($0)) }


      return .stream { continuation in
        continuation.yield(.started)
        defer { continuation.yield(.finished) }

//        continuation.yield(
//          await .response(Result { try await environment.fetch(42) })
//          await .repsonse(.success(try environment.fetch(42)))
//        )
      }
//      .catchToEffect()

  case let .response(.success(fact)):
    state = fact
    return .none

  case .response(.failure):
    return .none
  }
}



@available(iOS 15, *)
extension Effect where Failure == Never {
  static func stream(
    _ build: @escaping (AsyncStream<Output>.Continuation) async -> Void
  ) -> Self {
    AsyncStream(Output.self) { continuation in
      Task {
        await build(continuation)
        continuation.finish()
      }
    }
      .publisher
      .catch { _ in Empty() }
      .eraseToEffect()
  }
}

@available(iOS 15, *)
extension Effect  {

  struct Continuation<Output> {
    fileprivate let continuation: AsyncThrowingStream<Output, Error>.Continuation
    func yield(_ output: Output) {
      self.continuation.yield(output)
    }
    func finish() {
      self.continuation.finish(throwing: nil)
    }
  }

  static func throwingStream(
    _ build: @escaping (Continuation<Output>) async throws -> Void
  ) -> Effect<Output, Error> {
    AsyncThrowingStream(Output.self) { continuation in
      Task {
        // TODO: error is being swalled
        try await build(Continuation(continuation: continuation))
      }
    }
      .publisher
      .eraseToEffect()
  }

  func `catch`(`catch`: @escaping (Error) -> Output) -> Effect<Output, Never> {
    self
      .catch { Just(`catch`($0)) }
      .eraseToEffect()
  }
}

// AsyncSequence -> Publisher
@available(iOS 15.0, macOS 12.0, *)
public struct AsyncSequencePublisher<AsyncSequenceType> : Publisher where AsyncSequenceType : AsyncSequence {
  public typealias Output = AsyncSequenceType.Element
  public typealias Failure = Error

  let sequence: AsyncSequenceType

  public init(_ sequence: AsyncSequenceType) {
    self.sequence = sequence
  }

  fileprivate class ASPSubscription<S> : Subscription
  where S : Subscriber, S.Failure == Error, S.Input == AsyncSequenceType.Element {
    private var taskHandle: Task<(), Never>?
    private let innerActor = Inner()

    /// Ideally this wouldn't be needed and the ASPSubscriber could be an actor itself but due to issues in Xcode 13 beta 1 and 2
    /// continuations can't safely be resumed from actor contexts so this separate actor is needed to manage the demand and th
    /// continuation but to return it instead of resuming it directly. The callers of `add(demand:)` and
    /// `getContinuationToFireOnCancelation` shoudl always resume the returned value immediately
    private actor Inner {
      var demand: Subscribers.Demand = .none
      var demandUpdatedContinuation: CheckedContinuation<Void, Never>?

      /// Returns immediately if there is demand for an additional item from the subscriber or awaits an increase in demand
      /// then will return when there is some demand (or the task has been cancelled and the continuation fired)
      fileprivate func waitUntilReadyForMore() async {
        if demand > 0 {
          demand -= 1
          return
        }

        let _: Void = await withCheckedContinuation { continuation in
          demandUpdatedContinuation = continuation
        }
      }

      /// Update the tracked demand for the publisher
      /// - Parameter demand: The additional demand for the publisher
      /// - Returns: A continuation that must be resumed off the actor context immediatly
      func add(demand: Subscribers.Demand) -> CheckedContinuation<Void, Never>? {
        defer { demandUpdatedContinuation = nil }
        self.demand += demand
        guard demand > 0 else { return nil }
        return demandUpdatedContinuation
      }


      /// This is used to prevent being permanently stuck awaiting the continuation if the task has been cancelled
      /// - Returns: Continuation to resume to allow cancellation to complete
      func getContinuationToFireOnCancelation()  -> CheckedContinuation<Void, Never>? {
        defer { demandUpdatedContinuation = nil }
        return demandUpdatedContinuation
      }
    }

    /// Kicks off the main loop over the async sequence. Does the main work within the for loop over the async seqence
    /// - Parameters:
    ///   - seq: The AsyncSequence that is the source
    ///   - sub: The Subscriber to this Subscription
    private func mainLoop(seq: AsyncSequenceType, sub: S) {
      // taskHandle is kept for cancelation
      taskHandle = Task {
        do {
          try await withTaskCancellationHandler {
            Task.detached {
              let cont = await self.innerActor.getContinuationToFireOnCancelation()
              cont?.resume()
            }
          } operation: {
            for try await element in seq {
              // Check for demand before providing the first item
              await self.innerActor.waitUntilReadyForMore()

              try Task.checkCancellation()
//              guard !Task.isCancelled else { return } // Exit if cancelled

              let newDemand = sub.receive(element) // Pass on the item
              let cont = await self.innerActor.add(demand: newDemand)
              assert(cont == nil,
                     "If we are't waiting on the demand the continuation will always be nil")
              // cont should always be nil as it will only be set when this loop is
              // waiting on demand
              cont?.resume()

            }
            // Finished the AsyncSequence so finish the subcription
            sub.receive(completion: .finished)
            return
          }
        } catch {
          // Cancel means the subscriber shouldn't get more, even errors so exit
          if error is CancellationError { return }
          sub.receive(completion: .failure(error))
        }
      }
    }

    init(sequence: AsyncSequenceType, subscriber: S) {
      self.mainLoop(seq: sequence, sub: subscriber)
    }

    func request(_ demand: Subscribers.Demand) {
      Task {
        let cont = await innerActor.add(demand: demand)
        cont?.resume()
      }
    }

    func cancel() {
      // Part of the Cancellable / Publisher API - Stop the main loop
      taskHandle?.cancel()
    }

    deinit {
      cancel()
    }
  }

  public func receive<S>(subscriber: S)
  where S : Subscriber, Error == S.Failure, AsyncSequenceType.Element == S.Input {
    let subscription = ASPSubscription(sequence: sequence, subscriber: subscriber)
    subscriber.receive(subscription: subscription)
  }
}

@available(iOS 15.0, macOS 12.0, *)
extension AsyncSequence {
  ///  Returns a Combine publisher for the sequence - Not recomended for production. Structured Concurrency demonstration
  ///  not performance tested
  public var publisher: AsyncSequencePublisher<Self> {
    AsyncSequencePublisher(self)
  }
}





/// The ``Effect`` type encapsulates a unit of work that can be run in the outside world, and can
/// feed data back to the ``Store``. It is the perfect place to do side effects, such as network
/// requests, saving/loading from disk, creating timers, interacting with dependencies, and more.
///
/// Effects are returned from reducers so that the ``Store`` can perform the effects after the
/// reducer is done running. It is important to note that ``Store`` is not thread safe, and so all
/// effects must receive values on the same thread, **and** if the store is being used to drive UI
/// then it must receive values on the main thread.
///
/// An effect simply wraps a `Publisher` value and provides some convenience initializers for
/// constructing some common types of effects.
public struct Effect<Output, Failure: Error>: Publisher {
  public let upstream: AnyPublisher<Output, Failure>

  /// Initializes an effect that wraps a publisher. Each emission of the wrapped publisher will be
  /// emitted by the effect.
  ///
  /// This initializer is useful for turning any publisher into an effect. For example:
  ///
  /// ```swift
  /// Effect(
  ///   NotificationCenter.default
  ///     .publisher(for: UIApplication.userDidTakeScreenshotNotification)
  /// )
  /// ```
  ///
  /// Alternatively, you can use the `.eraseToEffect()` method that is defined on the `Publisher`
  /// protocol:
  ///
  /// ```swift
  /// NotificationCenter.default
  ///   .publisher(for: UIApplication.userDidTakeScreenshotNotification)
  ///   .eraseToEffect()
  /// ```
  ///
  /// - Parameter publisher: A publisher.
  public init<P: Publisher>(_ publisher: P) where P.Output == Output, P.Failure == Failure {
    self.upstream = publisher.eraseToAnyPublisher()
  }

  public func receive<S>(
    subscriber: S
  ) where S: Combine.Subscriber, Failure == S.Failure, Output == S.Input {
    self.upstream.subscribe(subscriber)
  }

  /// Initializes an effect that immediately emits the value passed in.
  ///
  /// - Parameter value: The value that is immediately emitted by the effect.
  public init(value: Output) {
    self.init(Just(value).setFailureType(to: Failure.self))
  }

  /// Initializes an effect that immediately fails with the error passed in.
  ///
  /// - Parameter error: The error that is immediately emitted by the effect.
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

  /// An effect that does nothing and completes immediately. Useful for situations where you must
  /// return an effect, but you don't need to do anything.
  public static var none: Effect {
    Empty(completeImmediately: true).eraseToEffect()
  }

  /// Creates an effect that can supply a single value asynchronously in the future.
  ///
  /// This can be helpful for converting APIs that are callback-based into ones that deal with
  /// ``Effect``s.
  ///
  /// For example, to create an effect that delivers an integer after waiting a second:
  ///
  /// ```swift
  /// Effect<Int, Never>.future { callback in
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
  /// Effect<Int, Never>.future { callback in
  ///   DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
  ///     callback(.success(42))
  ///     callback(.success(1729)) // Will not be emitted by the effect
  ///   }
  /// }
  /// ```
  ///
  ///  If you need to deliver more than one value to the effect, you should use the ``Effect``
  ///  initializer that accepts a ``Subscriber`` value.
  ///
  /// - Parameter attemptToFulfill: A closure that takes a `callback` as an argument which can be
  ///   used to feed it `Result<Output, Failure>` values.
  public static func future(
    _ attemptToFulfill: @escaping (@escaping (Result<Output, Failure>) -> Void) -> Void
  ) -> Effect {
    Deferred {
      Future { callback in
        attemptToFulfill { result in callback(result) }
      }
    }
    .eraseToEffect()
  }

  /// Initializes an effect that lazily executes some work in the real world and synchronously sends
  /// that data back into the store.
  ///
  /// For example, to load a user from some JSON on the disk, one can wrap that work in an effect:
  ///
  /// ```swift
  /// Effect<User, Error>.result {
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
  public static func result(_ attemptToFulfill: @escaping () -> Result<Output, Failure>) -> Self {
    Deferred { Future { $0(attemptToFulfill()) } }.eraseToEffect()
  }

  /// Initializes an effect from a callback that can send as many values as it wants, and can send
  /// a completion.
  ///
  /// This initializer is useful for bridging callback APIs, delegate APIs, and manager APIs to the
  /// ``Effect`` type. One can wrap those APIs in an Effect so that its events are sent through the
  /// effect, which allows the reducer to handle them.
  ///
  /// For example, one can create an effect to ask for access to `MPMediaLibrary`. It can start by
  /// sending the current status immediately, and then if the current status is `notDetermined` it
  /// can request authorization, and once a status is received it can send that back to the effect:
  ///
  /// ```swift
  /// Effect.run { subscriber in
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
  ///   When the ``Effect`` is completed, the cancellable will be used to clean up any resources
  ///   created when the effect was started.
  public static func run(
    _ work: @escaping (Effect.Subscriber) -> Cancellable
  ) -> Self {
    AnyPublisher.create(work).eraseToEffect()
  }

  /// Concatenates a variadic list of effects together into a single effect, which runs the effects
  /// one after the other.
  ///
  /// - Warning: Combine's `Publishers.Concatenate` operator, which this function uses, can leak
  ///   when its suffix is a `Publishers.MergeMany` operator, which is used throughout the
  ///   Composable Architecture in functions like ``Reducer/combine(_:)-1ern2``.
  ///
  ///   Feedback filed: <https://gist.github.com/mbrandonw/611c8352e1bd1c22461bd505e320ab58>
  ///
  /// - Parameter effects: A variadic list of effects.
  /// - Returns: A new effect
  public static func concatenate(_ effects: Effect...) -> Effect {
    .concatenate(effects)
  }

  /// Concatenates a collection of effects together into a single effect, which runs the effects one
  /// after the other.
  ///
  /// - Warning: Combine's `Publishers.Concatenate` operator, which this function uses, can leak
  ///   when its suffix is a `Publishers.MergeMany` operator, which is used throughout the
  ///   Composable Architecture in functions like ``Reducer/combine(_:)-1ern2``.
  ///
  ///   Feedback filed: <https://gist.github.com/mbrandonw/611c8352e1bd1c22461bd505e320ab58>
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
        effects = effects.append(effect).eraseToEffect()
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
    Publishers.MergeMany(effects).eraseToEffect()
  }

  /// Creates an effect that executes some work in the real world that doesn't need to feed data
  /// back into the store.
  ///
  /// - Parameter work: A closure encapsulating some work to execute in the real world.
  /// - Returns: An effect.
  public static func fireAndForget(_ work: @escaping () -> Void) -> Effect {
    // NB: Ideally we'd return a `Deferred` wrapping an `Empty(completeImmediately: true)`, but
    //     due to a bug in iOS 13.2 that publisher will never complete. The bug was fixed in
    //     iOS 13.3, but to remain compatible with iOS 13.2 and higher we need to do a little
    //     trickery to make sure the deferred publisher completes.
    Deferred { () -> Publishers.CompactMap<Result<Output?, Failure>.Publisher, Output> in
      work()
      return Just<Output?>(nil)
        .setFailureType(to: Failure.self)
        .compactMap { $0 }
    }
    .eraseToEffect()
  }

  /// Transforms all elements from the upstream effect with a provided closure.
  ///
  /// - Parameter transform: A closure that transforms the upstream effect's output to a new output.
  /// - Returns: A publisher that uses the provided closure to map elements from the upstream effect
  ///   to new elements that it then publishes.
  public func map<T>(_ transform: @escaping (Output) -> T) -> Effect<T, Failure> {
    .init(self.map(transform) as Publishers.Map<Self, T>)
  }
}

extension Effect where Failure == Swift.Error {
  /// Initializes an effect that lazily executes some work in the real world and synchronously sends
  /// that data back into the store.
  ///
  /// For example, to load a user from some JSON on the disk, one can wrap that work in an effect:
  ///
  /// ```swift
  /// Effect<User, Error>.catching {
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
  public static func catching(_ work: @escaping () throws -> Output) -> Self {
    .future { $0(Result { try work() }) }
  }
}

extension Publisher {
  /// Turns any publisher into an ``Effect``.
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
  public func eraseToEffect() -> Effect<Output, Failure> {
    Effect(self)
  }

  /// Turns any publisher into an ``Effect`` that cannot fail by wrapping its output and failure in
  /// a result.
  ///
  /// This can be useful when you are working with a failing API but want to deliver its data to an
  /// action that handles both success and failure.
  ///
  /// ```swift
  /// case .buttonTapped:
  ///   return fetchUser(id: 1)
  ///     .catchToEffect()
  ///     .map(ProfileAction.userResponse)
  /// ```
  ///
  /// - Returns: An effect that wraps `self`.
  public func catchToEffect() -> Effect<Result<Output, Failure>, Never> {
    self.map(Result.success)
      .catch { Just(.failure($0)) }
      .eraseToEffect()
  }

  /// Turns any publisher into an ``Effect`` for any output and failure type by ignoring all output
  /// and any failure.
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
  public func fireAndForget<NewOutput, NewFailure>(
    outputType: NewOutput.Type = NewOutput.self,
    failureType: NewFailure.Type = NewFailure.self
  ) -> Effect<NewOutput, NewFailure> {
    return
      self
      .flatMap { _ in Empty() }
      .catch { _ in Empty() }
      .eraseToEffect()
  }
}
