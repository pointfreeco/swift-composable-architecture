import Combine
import CustomDump
import Foundation
import XCTestDynamicOverlay

/// A testable runtime for a reducer.
///
/// This object aids in writing expressive and exhaustive tests for features built in the
/// Composable Architecture. It allows you to send a sequence of actions to the store, and each
/// step of the way you must assert exactly how state changed, and how effect emissions were fed
/// back into the system.
///
/// There are multiple ways the test store forces you to exhaustively assert on how your feature
/// behaves:
///
///   * After each action is sent you must describe precisely how the state changed from before
///     the action was sent to after it was sent.
///
///     If even the smallest piece of data differs the test will fail. This guarantees that you
///     are proving you know precisely how the state of the system changes.
///
///   * Sending an action can sometimes cause an effect to be executed, and if that effect emits
///     an action that is fed back into the system, you **must** explicitly assert that you expect
///     to receive that action from the effect, _and_ you must assert how state changed as a
///     result.
///
///     If you try to send another action before you have handled all effect emissions the
///     assertion will fail. This guarantees that you do not accidentally forget about an effect
///     emission, and that the sequence of steps you are describing will mimic how the application
///     behaves in reality.
///
///   * All effects must complete by the time the assertion has finished running the steps you
///     specify.
///
///     If at the end of the assertion there is still an in-flight effect running, the assertion
///     will fail. This helps exhaustively prove that you know what effects are in flight and
///     forces you to prove that effects will not cause any future changes to your state.
///
/// For example, given a simple counter reducer:
///
/// ```swift
/// struct Counter: ReducerProtocol {
///   struct State: Equatable {
///     var count = 0
///   }
///
///   enum Action {
///     case decrementButtonTapped
///     case incrementButtonTapped
///   }
///
///   func reduce(
///     into state: inout State, action: Action
///   ) -> EffectTask<Action> {
///     switch action {
///     case .decrementButtonTapped:
///       state.count -= 1
///       return .none
///
///     case .incrementButtonTapped:
///       state.count += 1
///       return .none
///     }
///   }
/// }
/// ```
///
/// One can assert against its behavior over time:
///
/// ```swift
/// @MainActor
/// class CounterTests: XCTestCase {
///   func testCounter() async {
///     let store = TestStore(
///       // Given a counter state of 0
///       initialState: Counter.State(count: 0),
///       reducer: Counter()
///     )
///
///     // When the increment button is tapped
///     await store.send(.incrementButtonTapped) {
///       // Then the count should be 1
///       $0.count = 1
///     }
///   }
/// }
/// ```
///
/// Note that in the trailing closure of `.send(.incrementButtonTapped)` we are given a single
/// mutable value of the state before the action was sent, and it is our job to mutate the value
/// to match the state after the action was sent. In this case the `count` field changes to `1`.
///
/// For a more complex example, consider the following bare-bones search feature that uses a
/// clock and cancel token to debounce requests:
///
/// ```swift
/// struct Search: ReducerProtocol {
///   struct State: Equatable {
///     var query = ""
///     var results: [String] = []
///   }
///
///   enum Action: Equatable {
///     case queryChanged(String)
///     case response([String])
///   }
///
///   @Dependency(\.apiClient) var apiClient
///   @Dependency(\.continuousClock) var clock
///
///   func reduce(
///     into state: inout State, action: Action
///   ) -> EffectTask<Action> {
///     switch action {
///     case let .queryChanged(query):
///       enum SearchID {}
///
///       state.query = query
///       return .run { send in
///         try await self.clock.sleep(for: 0.5)
///
///         guard let results = try? await self.apiClient.search(query)
///         else { return }
///
///         await send(.response(results))
///       }
///       .cancellable(id: SearchID.self, cancelInFlight: true)
///
///     case let .response(results):
///       state.results = results
///       return .none
///     }
///   }
/// }
/// ```
///
/// It can be fully tested by overriding the `continuousClock` and `apiClient` dependencies with
/// values that are fully controlled and deterministic:
///
/// ```swift
/// let store = TestStore(
///   initialState: Search.State(),
///   reducer: Search
/// )
///
/// // Create a test clock to control the timing of effects
/// let clock = TestClock
/// store.dependencies.continuousClock = clock
///
/// // Simulate a search response with one item
/// store.dependencies.apiClient.search = { _ in
///   ["Composable Architecture"]
/// }
///
/// // Change the query
/// await store.send(.searchFieldChanged("c") {
///   // Assert that state updates accordingly
///   $0.query = "c"
/// }
///
/// // Advance the clock by a period shorter than the debounce
/// await clock.advance(by: 0.25)
///
/// // Change the query again
/// await store.send(.searchFieldChanged("co") {
///   $0.query = "co"
/// }
///
/// // Advance the clock to the debounce duration
/// await clock.advance(by: 0.5)
///
/// // Assert that the expected response is received
/// await store.receive(.response(["Composable Architecture"])) {
///   // Assert that state updates accordingly
///   $0.results = ["Composable Architecture"]
/// }
/// ```
///
/// This test is proving that the debounced network requests are correctly canceled when we do not
/// wait longer than the 0.5 seconds, because if it wasn't and it delivered an action when we did
/// not expect it would cause a test failure.
public final class TestStore<State, Action, ScopedState, ScopedAction, Environment> {
  /// The current dependencies.
  ///
  /// The dependencies define the execution context that your feature runs in. They can be
  /// modified throughout the test store's lifecycle in order to influence how your feature
  /// produces effects.
  public var dependencies: DependencyValues {
    _read { yield self.reducer.dependencies }
    _modify { yield &self.reducer.dependencies }
  }

  /// The current environment.
  ///
  /// The environment can be modified throughout a test store's lifecycle in order to influence
  /// how it produces effects. This can be handy for testing flows that require a dependency to
  /// start in a failing state and then later change into a succeeding state:
  ///
  /// ```swift
  /// // Start dependency endpoint in a failing state
  /// store.environment.client.fetch = { _ in throw FetchError() }
  /// await store.send(.buttonTapped)
  /// await store.receive(.response(.failure(FetchError())) {
  ///   …
  /// }
  ///
  /// // Change dependency endpoint into a succeeding state
  /// await store.environment.client.fetch = { "Hello \($0)!" }
  /// await store.send(.buttonTapped)
  /// await store.receive(.response(.success("Hello Blob!"))) {
  ///   …
  /// }
  /// ```
  public var environment: Environment {
    _read { yield self._environment.wrappedValue }
    _modify { yield &self._environment.wrappedValue }
  }

  /// The current state.
  ///
  /// When read from a trailing closure assertion in ``send(_:_:file:line:)-6s1gq`` or
  /// ``receive(_:timeout:_:file:line:)-8yd62``, it will equal the `inout` state passed to the closure.
  public var state: State {
    self.reducer.state
  }

  /// The timeout to await for in-flight effects.
  ///
  /// This is the default timeout used in all methods that take an optional timeout, such as
  /// ``receive(_:timeout:_:file:line:)-8yd62`` and ``finish(timeout:file:line:)-7pmv3``.
  public var timeout: UInt64

  private var _environment: Box<Environment>
  private let file: StaticString
  private let fromScopedAction: (ScopedAction) -> Action
  private var line: UInt
  let reducer: TestReducer<State, Action>
  private let store: Store<State, TestReducer<State, Action>.TestAction>
  private let toScopedState: (State) -> ScopedState

  public init<Reducer: ReducerProtocol>(
    initialState: State,
    reducer: Reducer,
    file: StaticString = #file,
    line: UInt = #line
  )
  where
    Reducer.State == State,
    Reducer.Action == Action,
    State == ScopedState,
    Action == ScopedAction,
    Environment == Void
  {
    let reducer = TestReducer(Reduce(reducer), initialState: initialState)
    self._environment = .init(wrappedValue: ())
    self.file = file
    self.fromScopedAction = { $0 }
    self.line = line
    self.reducer = reducer
    self.store = Store(initialState: initialState, reducer: reducer)
    self.timeout = 100 * NSEC_PER_MSEC
    self.toScopedState = { $0 }
  }

  @available(
    iOS,
    deprecated: 9999.0,
    message:
      """
      'Reducer' has been deprecated in favor of 'ReducerProtocol'.

      See the migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/reducerprotocol
      """
  )
  @available(
    macOS,
    deprecated: 9999.0,
    message:
      """
      'Reducer' has been deprecated in favor of 'ReducerProtocol'.

      See the migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/reducerprotocol
      """
  )
  @available(
    tvOS,
    deprecated: 9999.0,
    message:
      """
      'Reducer' has been deprecated in favor of 'ReducerProtocol'.

      See the migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/reducerprotocol
      """
  )
  @available(
    watchOS,
    deprecated: 9999.0,
    message:
      """
      'Reducer' has been deprecated in favor of 'ReducerProtocol'.

      See the migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/reducerprotocol
      """
  )
  public init(
    initialState: ScopedState,
    reducer: AnyReducer<ScopedState, ScopedAction, Environment>,
    environment: Environment,
    file: StaticString = #file,
    line: UInt = #line
  )
  where State == ScopedState, Action == ScopedAction {
    let environment = Box(wrappedValue: environment)
    let reducer = TestReducer(
      Reduce(
        reducer.pullback(state: \.self, action: .self, environment: { $0.wrappedValue }),
        environment: environment
      ),
      initialState: initialState
    )
    self._environment = environment
    self.file = file
    self.fromScopedAction = { $0 }
    self.line = line
    self.reducer = reducer
    self.store = Store(initialState: initialState, reducer: reducer)
    self.timeout = 100 * NSEC_PER_MSEC
    self.toScopedState = { $0 }
  }

  init(
    _environment: Box<Environment>,
    file: StaticString,
    fromScopedAction: @escaping (ScopedAction) -> Action,
    line: UInt,
    reducer: TestReducer<State, Action>,
    store: Store<State, TestReducer<State, Action>.Action>,
    timeout: UInt64 = 100 * NSEC_PER_MSEC,
    toScopedState: @escaping (State) -> ScopedState
  ) {
    self._environment = _environment
    self.file = file
    self.fromScopedAction = fromScopedAction
    self.line = line
    self.reducer = reducer
    self.store = store
    self.timeout = timeout
    self.toScopedState = toScopedState
  }

  // NB: Only needed until Xcode ships a macOS SDK that uses the 5.7 standard library.
  // See: https://forums.swift.org/t/xcode-14-rc-cannot-specialize-protocol-type/60171/15
  #if swift(>=5.7) && !os(macOS) && !targetEnvironment(macCatalyst)
    /// Suspends until all in-flight effects have finished, or until it times out.
    ///
    /// Can be used to assert that all effects have finished.
    ///
    /// - Parameter duration: The amount of time to wait before asserting.
    @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
    @MainActor
    public func finish(
      timeout duration: Duration? = nil,
      file: StaticString = #file,
      line: UInt = #line
    ) async {
      await self.finish(timeout: duration?.nanoseconds, file: file, line: line)
    }
  #endif

  /// Suspends until all in-flight effects have finished, or until it times out.
  ///
  /// Can be used to assert that all effects have finished.
  ///
  /// - Parameter nanoseconds: The amount of time to wait before asserting.
  @_disfavoredOverload
  @MainActor
  public func finish(
    timeout nanoseconds: UInt64? = nil,
    file: StaticString = #file,
    line: UInt = #line
  ) async {
    let nanoseconds = nanoseconds ?? self.timeout
    let start = DispatchTime.now().uptimeNanoseconds
    await Task.megaYield()
    while !self.reducer.inFlightEffects.isEmpty {
      guard start.distance(to: DispatchTime.now().uptimeNanoseconds) < nanoseconds
      else {
        let timeoutMessage =
          nanoseconds != self.self.timeout
          ? #"try increasing the duration of this assertion's "timeout""#
          : #"configure this assertion with an explicit "timeout""#
        let suggestion = """
          There are effects in-flight. If the effect that delivers this action uses a \
          clock/scheduler (via "receive(on:)", "delay", "debounce", etc.), make sure that you wait \
          enough time for it to perform the effect. If you are using a test \
          clock/scheduler, advance it so that the effects may complete, or consider using \
          an immediate clock/scheduler to immediately perform the effect instead.

          If you are not yet using a clock/scheduler, or can not use a clock/scheduler, \
          \(timeoutMessage).
          """

        XCTFail(
          """
          Expected effects to finish, but there are still effects in-flight\
          \(nanoseconds > 0 ? " after \(Double(nanoseconds)/Double(NSEC_PER_SEC)) seconds" : "").

          \(suggestion)
          """,
          file: file,
          line: line
        )
        return
      }
      await Task.yield()
    }
  }

  deinit {
    self.completed()
  }

  func completed() {
    if !self.reducer.receivedActions.isEmpty {
      var actions = ""
      customDump(self.reducer.receivedActions.map(\.action), to: &actions)
      XCTFail(
        """
        The store received \(self.reducer.receivedActions.count) unexpected \
        action\(self.reducer.receivedActions.count == 1 ? "" : "s") after this one: …

        Unhandled actions: \(actions)
        """,
        file: self.file, line: self.line
      )
    }
    for effect in self.reducer.inFlightEffects {
      XCTFail(
        """
        An effect returned for this action is still running. It must complete before the end of \
        the test. …

        To fix, inspect any effects the reducer returns for this action and ensure that all of \
        them complete by the end of the test. There are a few reasons why an effect may not have \
        completed:

        • If using async/await in your effect, it may need a little bit of time to properly \
        finish. To fix you can simply perform "await store.finish()" at the end of your test.

        • If an effect uses a clock/scheduler (via "receive(on:)", "delay", "debounce", etc.), \
        make sure that you wait enough time for it to perform the effect. If you are using \
        a test clock/scheduler, advance it so that the effects may complete, or consider \
        using an immediate clock/scheduler to immediately perform the effect instead.

        • If you are returning a long-living effect (timers, notifications, subjects, etc.), \
        then make sure those effects are torn down by marking the effect ".cancellable" and \
        returning a corresponding cancellation effect ("Effect.cancel") from another action, or, \
        if your effect is driven by a Combine subject, send it a completion.
        """,
        file: effect.file,
        line: effect.line
      )
    }
  }
}

extension TestStore where ScopedState: Equatable {
  /// Sends an action to the store and asserts when state changes.
  ///
  /// This method suspends in order to allow any effects to start. For example, if you
  /// track an analytics event in a ``EffectPublisher/fireAndForget(priority:_:)`` when an action is
  /// sent, you can assert on that behavior immediately after awaiting `store.send`:
  ///
  /// ```swift
  /// @MainActor
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
  ///
  /// This method suspends only for the duration until the effect _starts_ from sending the
  /// action. It does _not_ suspend for the duration of the effect.
  ///
  /// In order to suspend for the duration of the effect you can use its return value, a
  /// ``TestStoreTask``, which represents the lifecycle of the effect started from sending an
  /// action. You can use this value to suspend until the effect finishes, or to force the
  /// cancellation of the effect, which is helpful for effects that are tied to a view's lifecycle
  /// and not torn down when an action is sent, such as actions sent in SwiftUI's `task` view
  /// modifier.
  ///
  /// For example, if your feature kicks off a long-living effect when the view appears by using
  /// SwiftUI's `task` view modifier, then you can write a test for such a feature by explicitly
  /// canceling the effect's task after you make all assertions:
  ///
  /// ```swift
  /// let store = TestStore(...)
  ///
  /// // emulate the view appearing
  /// let task = await store.send(.task)
  ///
  /// // assertions
  ///
  /// // emulate the view disappearing
  /// await task.cancel()
  /// ```
  ///
  /// - Parameters:
  ///   - action: An action.
  ///   - updateExpectingResult: A closure that asserts state changed by sending the action to the
  ///     store. The mutable state sent to this closure must be modified to match the state of the
  ///     store after processing the given action. Do not provide a closure if no change is
  ///     expected.
  /// - Returns: A ``TestStoreTask`` that represents the lifecycle of the effect executed when
  ///   sending the action.
  @MainActor
  @discardableResult
  public func send(
    _ action: ScopedAction,
    _ updateExpectingResult: ((inout ScopedState) throws -> Void)? = nil,
    file: StaticString = #file,
    line: UInt = #line
  ) async -> TestStoreTask {
    if !self.reducer.receivedActions.isEmpty {
      var actions = ""
      customDump(self.reducer.receivedActions.map(\.action), to: &actions)
      XCTFail(
        """
        Must handle \(self.reducer.receivedActions.count) received \
        action\(self.reducer.receivedActions.count == 1 ? "" : "s") before sending an action: …

        Unhandled actions: \(actions)
        """,
        file: file, line: line
      )
    }
    var expectedState = self.toScopedState(self.state)
    let previousState = self.reducer.state
    let task = self.store
      .send(.init(origin: .send(self.fromScopedAction(action)), file: file, line: line))
    await self.reducer.effectDidSubscribe.stream.first(where: { _ in true })
    do {
      let currentState = self.state
      self.reducer.state = previousState
      defer { self.reducer.state = currentState }

      try self.expectedStateShouldMatch(
        expected: &expectedState,
        actual: self.toScopedState(currentState),
        modify: updateExpectingResult,
        file: file,
        line: line
      )
    } catch {
      XCTFail("Threw error: \(error)", file: file, line: line)
    }
    if "\(self.file)" == "\(file)" {
      self.line = line
    }
    // NB: Give concurrency runtime more time to kick off effects so users don't need to manually
    //     instrument their effects.
    await Task.megaYield(count: 20)
    return .init(rawValue: task, timeout: self.timeout)
  }

  /// Sends an action to the store and asserts when state changes.
  ///
  /// This method returns a ``TestStoreTask``, which represents the lifecycle of the effect
  /// started from sending an action. You can use this value to force the cancellation of the
  /// effect, which is helpful for effects that are tied to a view's lifecycle and not torn
  /// down when an action is sent, such as actions sent in SwiftUI's `task` view modifier.
  ///
  /// For example, if your feature kicks off a long-living effect when the view appears by using
  /// SwiftUI's `task` view modifier, then you can write a test for such a feature by explicitly
  /// canceling the effect's task after you make all assertions:
  ///
  /// ```swift
  /// let store = TestStore(...)
  ///
  /// // emulate the view appearing
  /// let task = await store.send(.task)
  ///
  /// // assertions
  ///
  /// // emulate the view disappearing
  /// await task.cancel()
  /// ```
  ///
  /// - Parameters:
  ///   - action: An action.
  ///   - updateExpectingResult: A closure that asserts state changed by sending the action to the
  ///     store. The mutable state sent to this closure must be modified to match the state of the
  ///     store after processing the given action. Do not provide a closure if no change is
  ///     expected.
  /// - Returns: A ``TestStoreTask`` that represents the lifecycle of the effect executed when
  ///   sending the action.
  @available(iOS, deprecated: 9999.0, message: "Call the async-friendly 'send' instead.")
  @available(macOS, deprecated: 9999.0, message: "Call the async-friendly 'send' instead.")
  @available(tvOS, deprecated: 9999.0, message: "Call the async-friendly 'send' instead.")
  @available(watchOS, deprecated: 9999.0, message: "Call the async-friendly 'send' instead.")
  @discardableResult
  public func send(
    _ action: ScopedAction,
    _ updateExpectingResult: ((inout ScopedState) throws -> Void)? = nil,
    file: StaticString = #file,
    line: UInt = #line
  ) -> TestStoreTask {
    if !self.reducer.receivedActions.isEmpty {
      var actions = ""
      customDump(self.reducer.receivedActions.map(\.action), to: &actions)
      XCTFail(
        """
        Must handle \(self.reducer.receivedActions.count) received \
        action\(self.reducer.receivedActions.count == 1 ? "" : "s") before sending an action: …

        Unhandled actions: \(actions)
        """,
        file: file, line: line
      )
    }
    var expectedState = self.toScopedState(self.state)
    let previousState = self.state
    let task = self.store
      .send(.init(origin: .send(self.fromScopedAction(action)), file: file, line: line))
    do {
      let currentState = self.state
      self.reducer.state = previousState
      defer { self.reducer.state = currentState }

      try self.expectedStateShouldMatch(
        expected: &expectedState,
        actual: self.toScopedState(currentState),
        modify: updateExpectingResult,
        file: file,
        line: line
      )
    } catch {
      XCTFail("Threw error: \(error)", file: file, line: line)
    }
    if "\(self.file)" == "\(file)" {
      self.line = line
    }

    return .init(rawValue: task, timeout: self.timeout)
  }

  private func expectedStateShouldMatch(
    expected: inout ScopedState,
    actual: ScopedState,
    modify: ((inout ScopedState) throws -> Void)? = nil,
    file: StaticString,
    line: UInt
  ) throws {
    let current = expected
    if let modify = modify {
      try modify(&expected)
    }

    if expected != actual {
      let difference =
        diff(expected, actual, format: .proportional)
        .map { "\($0.indent(by: 4))\n\n(Expected: −, Actual: +)" }
        ?? """
        Expected:
        \(String(describing: expected).indent(by: 2))

        Actual:
        \(String(describing: actual).indent(by: 2))
        """

      let messageHeading =
        modify != nil
        ? "A state change does not match expectation"
        : "State was not expected to change, but a change occurred"
      XCTFail(
        """
        \(messageHeading): …

        \(difference)
        """,
        file: file,
        line: line
      )
    } else if expected == current && modify != nil {
      XCTFail(
        """
        Expected state to change, but no change occurred.

        The trailing closure made no observable modifications to state. If no change to state is \
        expected, omit the trailing closure.
        """,
        file: file, line: line
      )
    }
  }
}

extension TestStore where ScopedState: Equatable, Action: Equatable {
  /// Asserts an action was received from an effect and asserts when state changes.
  ///
  /// - Parameters:
  ///   - expectedAction: An action expected from an effect.
  ///   - updateExpectingResult: A closure that asserts state changed by sending the action to the
  ///     store. The mutable state sent to this closure must be modified to match the state of the
  ///     store after processing the given action. Do not provide a closure if no change is
  ///     expected.
  @available(iOS, deprecated: 9999.0, message: "Call the async-friendly 'receive' instead.")
  @available(macOS, deprecated: 9999.0, message: "Call the async-friendly 'receive' instead.")
  @available(tvOS, deprecated: 9999.0, message: "Call the async-friendly 'receive' instead.")
  @available(watchOS, deprecated: 9999.0, message: "Call the async-friendly 'receive' instead.")
  public func receive(
    _ expectedAction: Action,
    _ updateExpectingResult: ((inout ScopedState) throws -> Void)? = nil,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    guard !self.reducer.receivedActions.isEmpty else {
      XCTFail(
        """
        Expected to receive an action, but received none.
        """,
        file: file, line: line
      )
      return
    }
    let (receivedAction, state) = self.reducer.receivedActions.removeFirst()
    if expectedAction != receivedAction {
      let difference = TaskResultDebugging.$emitRuntimeWarnings.withValue(false) {
        diff(expectedAction, receivedAction, format: .proportional)
          .map { "\($0.indent(by: 4))\n\n(Expected: −, Received: +)" }
          ?? """
          Expected:
          \(String(describing: expectedAction).indent(by: 2))

          Received:
          \(String(describing: receivedAction).indent(by: 2))
          """
      }

      XCTFail(
        """
        Received unexpected action: …

        \(difference)
        """,
        file: file, line: line
      )
    }
    var expectedState = self.toScopedState(self.state)
    do {
      try expectedStateShouldMatch(
        expected: &expectedState,
        actual: self.toScopedState(state),
        modify: updateExpectingResult,
        file: file,
        line: line
      )
    } catch {
      XCTFail("Threw error: \(error)", file: file, line: line)
    }
    self.reducer.state = state
    if "\(self.file)" == "\(file)" {
      self.line = line
    }
  }

  // NB: Only needed until Xcode ships a macOS SDK that uses the 5.7 standard library.
  // See: https://forums.swift.org/t/xcode-14-rc-cannot-specialize-protocol-type/60171/15
  #if swift(>=5.7) && !os(macOS) && !targetEnvironment(macCatalyst)
    /// Asserts an action was received from an effect and asserts how the state changes.
    ///
    /// - Parameters:
    ///   - expectedAction: An action expected from an effect.
    ///   - duration: The amount of time to wait for the expected action.
    ///   - updateExpectingResult: A closure that asserts state changed by sending the action to
    ///     the store. The mutable state sent to this closure must be modified to match the state
    ///     of the store after processing the given action. Do not provide a closure if no change
    ///     is expected.
    @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
    @MainActor
    public func receive(
      _ expectedAction: Action,
      timeout duration: Duration,
      _ updateExpectingResult: ((inout ScopedState) throws -> Void)? = nil,
      file: StaticString = #file,
      line: UInt = #line
    ) async {
      await self.receive(
        expectedAction,
        timeout: duration.nanoseconds,
        updateExpectingResult,
        file: file,
        line: line
      )
    }
  #endif

  /// Asserts an action was received from an effect and asserts how the state changes.
  ///
  /// - Parameters:
  ///   - expectedAction: An action expected from an effect.
  ///   - nanoseconds: The amount of time to wait for the expected action.
  ///   - updateExpectingResult: A closure that asserts state changed by sending the action to the
  ///     store. The mutable state sent to this closure must be modified to match the state of the
  ///     store after processing the given action. Do not provide a closure if no change is
  ///     expected.
  @MainActor
  public func receive(
    _ expectedAction: Action,
    timeout nanoseconds: UInt64? = nil,
    _ updateExpectingResult: ((inout ScopedState) throws -> Void)? = nil,
    file: StaticString = #file,
    line: UInt = #line
  ) async {
    let nanoseconds = nanoseconds ?? self.timeout

    guard !self.reducer.inFlightEffects.isEmpty
    else {
      { self.receive(expectedAction, updateExpectingResult, file: file, line: line) }()
      return
    }

    await Task.megaYield()
    let start = DispatchTime.now().uptimeNanoseconds
    while !Task.isCancelled {
      await Task.detached(priority: .background) { await Task.yield() }.value

      guard self.reducer.receivedActions.isEmpty
      else { break }

      guard start.distance(to: DispatchTime.now().uptimeNanoseconds) < nanoseconds
      else {
        let suggestion: String
        if self.reducer.inFlightEffects.isEmpty {
          suggestion = """
            There are no in-flight effects that could deliver this action. Could the effect you \
            expected to deliver this action have been cancelled?
            """
        } else {
          let timeoutMessage =
            nanoseconds != self.timeout
            ? #"try increasing the duration of this assertion's "timeout""#
            : #"configure this assertion with an explicit "timeout""#
          suggestion = """
            There are effects in-flight. If the effect that delivers this action uses a \
            clock/scheduler (via "receive(on:)", "delay", "debounce", etc.), make sure that you \
            wait enough time for it to perform the effect. If you are using a test \
            clock/scheduler, advance it so that the effects may complete, or consider using \
            an immediate clock/scheduler to immediately perform the effect instead.

            If you are not yet using a clock/scheduler, or can not use a clock/scheduler, \
            \(timeoutMessage).
            """
        }
        XCTFail(
          """
          Expected to receive an action, but received none\
          \(nanoseconds > 0 ? " after \(Double(nanoseconds)/Double(NSEC_PER_SEC)) seconds" : "").

          \(suggestion)
          """,
          file: file,
          line: line
        )
        return
      }
    }

    guard !Task.isCancelled
    else { return }

    { self.receive(expectedAction, updateExpectingResult, file: file, line: line) }()
    await Task.megaYield()
  }
}

extension TestStore {
  /// Scopes a store to assert against scoped state and actions.
  ///
  /// Useful for testing view store-specific state and actions.
  ///
  /// - Parameters:
  ///   - toScopedState: A function that transforms the reducer's state into scoped state. This
  ///     state will be asserted against as it is mutated by the reducer. Useful for testing view
  ///     store state transformations.
  ///   - fromScopedAction: A function that wraps a more scoped action in the reducer's action.
  ///     Scoped actions can be "sent" to the store, while any reducer action may be received.
  ///     Useful for testing view store action transformations.
  public func scope<S, A>(
    state toScopedState: @escaping (ScopedState) -> S,
    action fromScopedAction: @escaping (A) -> ScopedAction
  ) -> TestStore<State, Action, S, A, Environment> {
    .init(
      _environment: self._environment,
      file: self.file,
      fromScopedAction: { self.fromScopedAction(fromScopedAction($0)) },
      line: self.line,
      reducer: self.reducer,
      store: self.store,
      timeout: self.timeout,
      toScopedState: { toScopedState(self.toScopedState($0)) }
    )
  }

  /// Scopes a store to assert against scoped state.
  ///
  /// Useful for testing view store-specific state.
  ///
  /// - Parameter toScopedState: A function that transforms the reducer's state into scoped state.
  ///   This state will be asserted against as it is mutated by the reducer. Useful for testing
  ///   view store state transformations.
  public func scope<S>(
    state toScopedState: @escaping (ScopedState) -> S
  ) -> TestStore<State, Action, S, ScopedAction, Environment> {
    self.scope(state: toScopedState, action: { $0 })
  }
}

/// The type returned from ``TestStore/send(_:_:file:line:)-6s1gq`` that represents the lifecycle
/// of the effect started from sending an action.
///
/// You can use this value in tests to cancel the effect started from sending an action:
///
/// ```swift
/// // Simulate the "task" view modifier invoking some async work
/// let task = store.send(.task)
///
/// // Simulate the view cancelling this work on dismissal
/// await task.cancel()
/// ```
///
/// You can also explicitly wait for an effect to finish:
///
/// ```swift
/// store.send(.startTimerButtonTapped)
///
/// await clock.advance(by: .seconds(1))
/// await store.receive(.timerTick) { $0.elapsed = 1 }
///
/// // Wait for cleanup effects to finish before completing the test
/// await store.send(.stopTimerButtonTapped).finish()
/// ```
///
/// See ``TestStore/finish(timeout:file:line:)-7pmv3`` for the ability to await all in-flight effects in
/// the test store.
///
/// See ``ViewStoreTask`` for the analog provided to ``ViewStore``.
public struct TestStoreTask: Hashable, Sendable {
  fileprivate let rawValue: Task<Void, Never>?
  fileprivate let timeout: UInt64

  @_spi(Canary) public init(rawValue: Task<Void, Never>?, timeout: UInt64) {
    self.rawValue = rawValue
    self.timeout = timeout
  }

  /// Cancels the underlying task and waits for it to finish.
  public func cancel() async {
    self.rawValue?.cancel()
    await self.rawValue?.cancellableValue
  }

  // NB: Only needed until Xcode ships a macOS SDK that uses the 5.7 standard library.
  // See: https://forums.swift.org/t/xcode-14-rc-cannot-specialize-protocol-type/60171/15
  #if swift(>=5.7) && !os(macOS) && !targetEnvironment(macCatalyst)
    /// Asserts the underlying task finished.
    ///
    /// - Parameter duration: The amount of time to wait before asserting.
    @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
    public func finish(
      timeout duration: Duration? = nil,
      file: StaticString = #file,
      line: UInt = #line
    ) async {
      await self.finish(timeout: duration?.nanoseconds, file: file, line: line)
    }
  #endif

  /// Asserts the underlying task finished.
  ///
  /// - Parameter nanoseconds: The amount of time to wait before asserting.
  @_disfavoredOverload
  public func finish(
    timeout nanoseconds: UInt64? = nil,
    file: StaticString = #file,
    line: UInt = #line
  ) async {
    let nanoseconds = nanoseconds ?? self.timeout
    await Task.megaYield()
    do {
      try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask { await self.rawValue?.cancellableValue }
        group.addTask {
          try await Task.sleep(nanoseconds: nanoseconds)
          throw CancellationError()
        }
        try await group.next()
        group.cancelAll()
      }
    } catch {
      let timeoutMessage =
        nanoseconds != self.timeout
        ? #"try increasing the duration of this assertion's "timeout""#
        : #"configure this assertion with an explicit "timeout""#
      let suggestion = """
        If this task delivers its action using a clock/scheduler (via "sleep(for:)", \
        "timer(interval:)", etc.), make sure that you wait enough time for it to \
        perform its work. If you are using a test clock/scheduler, advance the scheduler so that \
        the effects may complete, or consider using an immediate clock/scheduler to immediately \
        perform the effect instead.

        If you are not yet using a clock/scheduler, or cannot use a clock/scheduler, \
        \(timeoutMessage).
        """

      XCTFail(
        """
        Expected task to finish, but it is still in-flight\
        \(nanoseconds > 0 ? " after \(Double(nanoseconds)/Double(NSEC_PER_SEC)) seconds" : "").

        \(suggestion)
        """,
        file: file,
        line: line
      )
    }
  }

  /// A Boolean value that indicates whether the task should stop executing.
  ///
  /// After the value of this property becomes `true`, it remains `true` indefinitely. There is
  /// no way to uncancel a task.
  public var isCancelled: Bool {
    self.rawValue?.isCancelled ?? true
  }
}

class TestReducer<State, Action>: ReducerProtocol {
  let base: Reduce<State, Action>
  var dependencies = { () -> DependencyValues in
    var dependencies = DependencyValues()
    dependencies.context = .test
    return dependencies
  }()
  let effectDidSubscribe = AsyncStream<Void>.streamWithContinuation()
  var inFlightEffects: Set<LongLivingEffect> = []
  var receivedActions: [(action: Action, state: State)] = []
  var state: State

  init(
    _ base: Reduce<State, Action>,
    initialState: State
  ) {
    self.base = base
    self.state = initialState
  }

  func reduce(into state: inout State, action: TestAction) -> EffectTask<TestAction> {
    let reducer = self.base.dependency(\.self, self.dependencies)

    let effects: EffectTask<Action>
    switch action.origin {
    case let .send(action):
      effects = reducer.reduce(into: &state, action: action)
      self.state = state

    case let .receive(action):
      effects = reducer.reduce(into: &state, action: action)
      self.receivedActions.append((action, state))
    }

    switch effects.operation {
    case .none:
      self.effectDidSubscribe.continuation.yield()
      return .none

    case .publisher, .run:
      let effect = LongLivingEffect(file: action.file, line: action.line)
      return
        effects
        .handleEvents(
          receiveSubscription: { [effectDidSubscribe, weak self] _ in
            self?.inFlightEffects.insert(effect)
            Task {
              await Task.megaYield()
              effectDidSubscribe.continuation.yield()
            }
          },
          receiveCompletion: { [weak self] _ in self?.inFlightEffects.remove(effect) },
          receiveCancel: { [weak self] in self?.inFlightEffects.remove(effect) }
        )
        .map { .init(origin: .receive($0), file: action.file, line: action.line) }
        .eraseToEffect()
    }
  }

  struct LongLivingEffect: Hashable {
    let id = UUID()
    let file: StaticString
    let line: UInt

    static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
      self.id.hash(into: &hasher)
    }
  }

  struct TestAction {
    let origin: Origin
    let file: StaticString
    let line: UInt

    enum Origin {
      case send(Action)
      case receive(Action)
    }
  }
}

extension Task where Success == Never, Failure == Never {
  @_spi(Internals) public static func megaYield(count: Int = 10) async {
    for _ in 1...count {
      await Task<Void, Never>.detached(priority: .background) { await Task.yield() }.value
    }
  }
}

// NB: Only needed until Xcode ships a macOS SDK that uses the 5.7 standard library.
// See: https://forums.swift.org/t/xcode-14-rc-cannot-specialize-protocol-type/60171/15
#if swift(>=5.7) && !os(macOS) && !targetEnvironment(macCatalyst)
  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  extension Duration {
    fileprivate var nanoseconds: UInt64 {
      UInt64(self.components.seconds) * NSEC_PER_SEC
        + UInt64(self.components.attoseconds) / 1_000_000_000
    }
  }
#endif
