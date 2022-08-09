extension AsyncStream {
  /// Initializes an `AsyncStream` from any `AsyncSequence`.
  ///
  /// Useful as a type eraser for live `AsyncSequence`-based dependencies.
  ///
  /// For example, your feature may want to subscribe to screenshot notifications. You can model
  /// this in your environment as a dependency returning an `AsyncStream`:
  ///
  /// ```swift
  /// struct ScreenshotsEnvironment {
  ///   var screenshots: () -> AsyncStream<Void>
  /// }
  /// ```
  ///
  /// Your "live" environment can supply a stream by erasing the appropriate
  /// `NotificationCenter.Notifications` async sequence:
  ///
  /// ```swift
  /// ScreenshotsEnvironment(
  ///   screenshots: {
  ///     AsyncStream(
  ///       NotificationCenter.default
  ///         .notifications(named: UIApplication.userDidTakeScreenshotNotification)
  ///         .map { _ in }
  ///     )
  ///   }
  /// )
  /// ```
  ///
  /// While your tests can use `AsyncStream.streamWithContinuation` to spin up a controllable stream
  /// for tests:
  ///
  /// ```swift
  /// let (stream, continuation) = AsyncStream<Void>.streamWithContinuation()
  ///
  /// let store = TestStore(
  ///   initialState: ScreenshotsState(),
  ///   reducer: screenshotsReducer,
  ///   environment: ScreenshotsEnvironment(
  ///     screenshots: { stream }
  ///   )
  /// )
  ///
  /// continuation.yield()  // Simulate a screenshot being taken.
  ///
  /// await store.receive(.screenshotTaken) { ... }
  /// ```
  ///
  /// - Parameters:
  ///   - sequence: An `AsyncSequence`.
  ///   - limit: The maximum number of elements to hold in the buffer. By default, this value is
  ///   unlimited. Use a `Continuation.BufferingPolicy` to buffer a specified number of oldest or
  ///   newest elements.
  public init<S: AsyncSequence & Sendable>(
    _ sequence: S,
    bufferingPolicy limit: Continuation.BufferingPolicy = .unbounded
  ) where S.Element == Element {
    self.init(bufferingPolicy: limit) { (continuation: Continuation) in
      let task = Task {
        do {
          for try await element in sequence {
            continuation.yield(element)
          }
        } catch {}
        continuation.finish()
      }
      continuation.onTermination =
        { _ in
          task.cancel()
        }
        // NB: This explicit cast is needed to work around a compiler bug in Swift 5.5.2
        as @Sendable (Continuation.Termination) -> Void
    }
  }

  /// Constructs and returns a stream along with its backing continuation.
  ///
  /// This is handy for immediately escaping the continuation from an async stream, which typically
  /// requires multiple steps:
  ///
  /// ```swift
  /// var _continuation: AsyncStream<Int>.Continuation!
  /// let stream = AsyncStream<Int> { continuation = $0 }
  /// let continuation = _continuation!
  ///
  /// // vs.
  ///
  /// let (stream, continuation) = AsyncStream<Int>.streamWithContinuation()
  /// ```
  ///
  /// This tool is usually used for tests where we need to supply an async sequence to a dependency
  /// endpoint and get access to its continuation so that we can emulate the dependency
  /// emitting data. For example, suppose you have a dependency exposing an async sequence for
  /// listening to notifications. To test this you can use `streamWithContinuation`:
  ///
  /// ```swift
  /// let notifications = AsyncStream<Void>.streamWithContinuation()
  ///
  /// let store = TestStore(
  ///   initialState: LongLivingEffectsState(),
  ///   reducer: longLivingEffectsReducer,
  ///   environment: LongLivingEffectsEnvironment(
  ///     notifications: { notifications.stream }
  ///   )
  /// )
  ///
  /// await store.send(.task)
  /// notifications.continuation.yield("Hello")
  /// await store.receive(.notification("Hello")) {
  ///   $0.message = "Hello"
  /// }
  /// ```
  ///
  /// > Warning: ⚠️ `AsyncStream` does not support multiple subscribers, therefore you can only use
  /// > this helper to test features that do not subscribe multiple times to the dependency
  /// > endpoint.
  ///
  /// - Parameters:
  ///   - elementType: The type of element the `AsyncStream` produces.
  ///   - limit: A Continuation.BufferingPolicy value to set the stream’s buffering behavior. By
  ///   default, the stream buffers an unlimited number of elements. You can also set the policy to
  ///   buffer a specified number of oldest or newest elements.
  /// - Returns: An `AsyncStream`.
  public static func streamWithContinuation(
    _ elementType: Element.Type = Element.self,
    bufferingPolicy limit: Continuation.BufferingPolicy = .unbounded
  ) -> (stream: Self, continuation: Continuation) {
    var continuation: Continuation!
    return (Self(elementType, bufferingPolicy: limit) { continuation = $0 }, continuation)
  }

  /// An `AsyncStream` that never emits and never completes unless cancelled.
  public static var never: Self {
    Self { _ in }
  }

  public static var finished: Self {
    Self { $0.finish() }
  }
}

extension AsyncThrowingStream where Failure == Error {
  /// Initializes an `AsyncStream` from any `AsyncSequence`.
  ///
  /// - Parameters:
  ///   - sequence: An `AsyncSequence`.
  ///   - limit: The maximum number of elements to hold in the buffer. By default, this value is
  ///   unlimited. Use a `Continuation.BufferingPolicy` to buffer a specified number of oldest or
  ///   newest elements.
  public init<S: AsyncSequence & Sendable>(
    _ sequence: S,
    bufferingPolicy limit: Continuation.BufferingPolicy = .unbounded
  ) where S.Element == Element {
    self.init(bufferingPolicy: limit) { (continuation: Continuation) in
      let task = Task {
        do {
          for try await element in sequence {
            continuation.yield(element)
          }
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
      continuation.onTermination =
        { _ in
          task.cancel()
        }
        // NB: This explicit cast is needed to work around a compiler bug in Swift 5.5.2
        as @Sendable (Continuation.Termination) -> Void
    }
  }

  /// Constructs and returns a stream along with its backing continuation.
  ///
  /// This is handy for immediately escaping the continuation from an async stream, which typically
  /// requires multiple steps:
  ///
  /// ```swift
  /// var _continuation: AsyncThrowingStream<Int, Error>.Continuation!
  /// let stream = AsyncThrowingStream<Int, Error> { continuation = $0 }
  /// let continuation = _continuation!
  ///
  /// // vs.
  ///
  /// let (stream, continuation) = AsyncThrowingStream<Int, Error>.streamWithContinuation()
  /// ```
  ///
  /// This tool is usually used for tests where we need to supply an async sequence to a dependency
  /// endpoint and get access to its continuation so that we can emulate the dependency
  /// emitting data. For example, suppose you have a dependency exposing an async sequence for
  /// listening to notifications. To test this you can use `streamWithContinuation`:
  ///
  /// ```swift
  /// let notifications = AsyncThrowingStream<Void>.streamWithContinuation()
  ///
  /// let store = TestStore(
  ///   initialState: LongLivingEffectsState(),
  ///   reducer: longLivingEffectsReducer,
  ///   environment: LongLivingEffectsEnvironment(
  ///     notifications: { notifications.stream }
  ///   )
  /// )
  ///
  /// await store.send(.task)
  /// notifications.continuation.yield("Hello")
  /// await store.receive(.notification("Hello")) {
  ///   $0.message = "Hello"
  /// }
  /// ```
  ///
  /// > Warning: ⚠️ `AsyncStream` does not support multiple subscribers, therefore you can only use
  /// > this helper to test features that do not subscribe multiple times to the dependency
  /// > endpoint.
  ///
  /// - Parameters:
  ///   - elementType: The type of element the `AsyncThrowingStream` produces.
  ///   - limit: A Continuation.BufferingPolicy value to set the stream’s buffering behavior. By
  ///   default, the stream buffers an unlimited number of elements. You can also set the policy to
  ///   buffer a specified number of oldest or newest elements.
  /// - Returns: An `AsyncThrowingStream`.
  public static func streamWithContinuation(
    _ elementType: Element.Type = Element.self,
    bufferingPolicy limit: Continuation.BufferingPolicy = .unbounded
  ) -> (stream: Self, continuation: Continuation) {
    var continuation: Continuation!
    return (Self(elementType, bufferingPolicy: limit) { continuation = $0 }, continuation)
  }

  /// An `AsyncThrowingStream` that never emits and never completes unless cancelled.
  public static var never: Self {
    Self { _ in }
  }

  public static var finished: Self {
    Self { $0.finish() }
  }
}

extension Task where Failure == Never {
  /// An async function that never returns.
  public static func never() async throws -> Success {
    for await element in AsyncStream<Success>.never {
      return element
    }
    throw _Concurrency.CancellationError()
  }
}

extension Task where Success == Never, Failure == Never {
  /// An async function that never returns.
  public static func never() async throws {
    for await _ in AsyncStream<Never>.never {}
    throw _Concurrency.CancellationError()
  }
}

/// A generic wrapper for isolating a mutable value to an actor.
///
/// This type is most useful when writing tests for when you want to inspect what happens inside
/// an effect. For example, suppose you have a feature such that when a button is tapped you
/// track some analytics:
///
/// ```swift
/// let reducer = Reducer<State, Action, Environment> { state, action, environment in
///   switch action {
///   case .buttonTapped:
///     return .fireAndForget { try await environment.analytics.track("Button Tapped") }
///   }
/// }
/// ```
///
/// Then, in tests we can construct an analytics client that appends events to a mutable array
/// rather than actually sending events to an analytics server. However, in order to do this in
/// a safe way we should use an actor, and ``ActorIsolated`` makes this easy:
///
/// ```swift
/// func testAnalytics() async {
///   let events = ActorIsolated<[String]>([])
///   let analytics = AnalyticsClient(
///     track: { event in
///       await events.withValue { $0.append(event) }
///     }
///   )
///
///   let store = TestStore(
///     initialState: State(),
///     reducer: reducer,
///     environment: Environment(analytics: analytics)
///   )
///
///   await store.send(.buttonTapped)
///
///   await events.withValue { XCTAssertEqual($0, ["Button Tapped"]) }
/// }
/// ```
@dynamicMemberLookup
public final actor ActorIsolated<Value: Sendable> {
  public var value: Value

  public init(_ value: Value) {
    self.value = value
  }

  public subscript<Subject>(dynamicMember keyPath: KeyPath<Value, Subject>) -> Subject {
    self.value[keyPath: keyPath]
  }

  /// Perform an operation with isolated access to the underlying value.
  ///
  /// - Parameters: operation: An operation to be performed on the actor with the underlying value.
  /// - Returns: The result of the operation.
  public func withValue<T: Sendable>(
    _ operation: @Sendable (inout Value) async throws -> T
  ) async rethrows -> T {
    var value = self.value
    defer { self.value = value }
    return try await operation(&value)
  }

  /// Overwrite the isolated value with a new value.
  ///
  /// - Parameter newValue: The value to replace the current isolated value with.
  public func setValue(_ newValue: Value) {
    self.value = newValue
  }
}

/// A generic wrapper for turning any non-`Sendable` type into a `Sendable` one, in an unchecked
/// manner.
///
/// Sometimes we need to use types that should be sendable but have not yet been audited for
/// sendability. If we feel confident that the type is truly sendable, and we don't want to blanket
/// disable concurrency warnings for a module via `@preconcurrency import`, then we can selectively
/// make that single type sendable by wrapping it in ``UncheckedSendable``.
///
/// > Note: By wrapping something in ``UncheckedSendable`` you are asking the compiler to trust
/// you that the type is safe to use from multiple threads, and the compiler cannot help you find
/// potential race conditions in your code.
@dynamicMemberLookup
@propertyWrapper
public struct UncheckedSendable<Value>: @unchecked Sendable {
  public var value: Value

  public init(_ value: Value) {
    self.value = value
  }

  public init(wrappedValue: Value) {
    self.value = wrappedValue
  }

  public var wrappedValue: Value {
    _read { yield self.value }
    _modify { yield &self.value }
  }

  public var projectedValue: Self {
    get { self }
    set { self = newValue }
  }

  public subscript<Subject>(dynamicMember keyPath: KeyPath<Value, Subject>) -> Subject {
    self.value[keyPath: keyPath]
  }

  public subscript<Subject>(dynamicMember keyPath: WritableKeyPath<Value, Subject>) -> Subject {
    _read { yield self.value[keyPath: keyPath] }
    _modify { yield &self.value[keyPath: keyPath] }
  }
}
