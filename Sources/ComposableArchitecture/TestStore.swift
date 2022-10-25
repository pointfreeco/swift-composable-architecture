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
/// See the dedicated <doc:Testing> article for detailed information on testing.
///
/// ## Exhaustive testing
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
///     specify, and all effect actions must be asserted on.
///
///     If at the end of the assertion there is still an in-flight effect running or an unreceived
///     action, the assertion will fail. This helps exhaustively prove that you know what effects
///     are in flight and forces you to prove that effects will not cause any future changes to
///     your state.
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
/// If the change made in the closure does not reflect reality, you will get a test failure with
/// a nicely formatted failure message letting you know exactly what went wrong:
///
/// ```swift
/// await store.send(.incrementButtonTapped) {
///   $0.count = 42
/// }
/// ```
///
/// ```
/// 🛑 A state change does not match expectation: …
///
///      TestStoreFailureTests.State(
///     −   count: 42
///     +   count: 1
///      )
///
/// (Expected: −, Actual: +)
/// ```
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
///     case searchResponse(TaskResult<[String]>)
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
///
///     case let .searchResponse(.success(results)):
///       state.results = results
///       return .none
///
///     case .searchResponse(.failure):
///       // Do error handling here.
///       return .none
///     }
///   }
/// }
/// ```
///
/// It can be fully tested by overriding the `apiClient` and `continuousClock` dependencies with
/// values that are fully controlled and deterministic:
///
/// ```swift
/// let store = TestStore(
///   initialState: Search.State(),
///   reducer: Search()
/// )
///
/// // Simulate a search response with one item
/// store.dependencies.dependencies.apiClient.search = { _ in
///   ["Composable Architecture"]
/// }
///
/// // Create a test clock to control the timing of effects
/// let clock = TestClock
/// store.dependencies.continuousClock = clock
///
/// // Change the query
/// await store.send(.searchFieldChanged("c") {
///   // Assert that state updates accordingly
///   $0.query = "c"
/// }
///
/// // Advance the clock by enough to get past the debounce
/// await clock.advance(by: 0.5)
///
/// // Assert that the expected response is received
/// await store.receive(.searchResponse(.success(["Composable Architecture"]))) {
///   $0.results = ["Composable Architecture"]
/// }
/// ```
///
/// This test is proving that when the search query changes some search responses are delivered
/// and state updates accordingly.
///
/// If we did not assert that the `searchResponse` action was received, we would get the following
/// test failure:
///
/// ```
/// 🛑 The store received 1 unexpected action after this one: …
///
///     Unhandled actions: [
///       [0]: Search.Action.seachResponse
///     ]
/// ```
///
/// This helpfully lets us know that we have no asserted on everything that happened in the feature,
/// which could be hiding a bug from us.
///
/// Or if we had sent another action before handling the effect's action we would have also gotten
/// a test failure:
///
/// ```
/// 🛑 Must handle 1 received action before sending an action: …
///
///     Unhandled actions: [
///       [0]: Search.Action.seachResponse
///     ]
/// ```
///
/// All of these types of failures help you prove that you know exactly how your feature evolves
/// as actions are sent into the system. If the library did not produce a test failure in these
/// situations it could be hiding subtle bugs in your code. For example, when the user clears the
/// search query you probably expect that the results are cleared and no search request is executed
/// since there is no query. This can be done like so:
///
/// ```swift
/// store.send(.queryChanged("")) {
///   $0.query = ""
///   $0.results = []
/// }
///
/// // No need to perform `store.receive` since you do not expect a search
/// // effect to execute.
/// ```
///
/// But, if in the future a bug is introduced causing a search request to be executed even when the
/// query is empty, you will get a test failure because a new effect is being created that is
/// not being asserted on. This is the power of exhaustive testing.
///
/// ## Non-exhaustive testing
///
/// While exhaustive testing can be powerful, it can also be a nuisance, especially when testing
/// how many features integrate together. This is why sometimes you may want to selectively test
/// in a non-exhaustive style.
///
/// > Tip: The concept of "non-exhaustive test store" was first introduced by
/// [Krzysztof Zabłocki][merowing.info] in a [blog post][exhaustive-testing-in-tca] and
/// [conference talk][Composable-Architecture-at-Scale], and then later became integrated into the
/// core library.
///
/// Test stores are exhaustive by default, which means you must assert on every state change, and
/// how ever effect feeds data back into the system, and you must make sure that all effects
/// complete before the test is finished. To turn of exhaustivity you can set ``exhaustivity``
/// to ``Exhaustivity/none``. When that is done the ``TestStore``'s behavior changes:
///
/// * The trailing closures of ``send(_:_:file:line:)-6s1gq`` and
/// ``receive(_:timeout:_:file:line:)`` no longer need to assert on all state changes. They
/// can assert on any subset of changes, and only if they make an incorrect mutation will a test
/// failure be raised.
/// * The ``send(_:_:file:line:)-6s1gq`` and ``receive(_:timeout:_:file:line:)`` methods are
/// allowed to be called even when actions have been received from effects that have not been
/// asserted on yet. Any pending actions will be cleared.
/// * Tests are allowed to finish with unasserted, received actions and inflight effects. No test
/// failures will be raised.
///
/// There is also a third option between full and no exhaustivity called ``Exhaustivity/partial``.
/// When it is set the test store behaves like when ``Exhaustivity/none`` is set, but with the added
/// behavior that any unasserted change causes a grey, informational box to appear next to each
/// assertion detailing the changes that were not asserted against. This allows you to see what
/// information you are choosing to ignore without causing a test failure. It can be useful in
/// tracking down bugs that happen in production but that aren't currently detected in tests.
///
/// This style of testing is most useful for testing the integration of multiple features where you
/// want to focus on just a certain slice of the behavior. Exhaustive testing can still be important
/// to use for leaf node features, where you truly do want to assert on everything happening inside
/// the feature.
///
/// For example, suppose you have a tab-based application where the 3rd tab is a login screen. The
/// user can fill in some data on the screen, then tap the "Submit" button, and then a series of
/// events happens to  log the user in. Once the user is logged in, the 3rd tab switches from a
/// login screen to a profile screen, _and_ the selected tab switches to the first tab, which is an
/// activity screen.
///
/// When writing tests for the login feature we will want to do that in the exhaustive style so that
/// we can prove exactly how the feature would behave in production. But, suppose we wanted to write
/// an integration test that proves after the user taps the "Login" button that ultimately the
/// selected tab switches to the first tab.
///
/// In order to test such a complex flow we must test the integration of multiple features, which
/// means dealing with complex, nested state and effects. We can emulate this flow in a test by
/// sending actions that mimic the user logging in, and then eventually assert that the selected
/// tab switched to activity:
///
/// ```swift
/// let store = TestStore(
///   initialState: App.State(),
///   reducer: App()
/// )
///
/// // 1️⃣ Emulate user tapping on submit button.
/// await store.send(.login(.submitButtonTapped)) {
///   $0.isLoading = true
/// }
///
/// // 2️⃣ Login feature performs API request to login, and
/// //    sends response back into system.
/// await store.receive(.login(.loginResponse(.success))) {
///   $0.isLoading = false
/// }
///
/// // 3️⃣ Login feature sends a delegate action to let parent
/// //    feature know it has successfully logged in.
/// await store.receive(.login(.delegate(.didLogin))) {
///   // 4️⃣ Assert how all of app state changes due to that action.
///   $0.authenticatedTab = .loggedIn(
///     Profile.State(...)
///   )
///   // 4️⃣ *Finally* assert that the selected tab switches to activity.
///   $0.selectedTab = .activity
/// }
/// ```
///
/// Doing this with exhaustive testing is verbose, and there are a few problems with this:
///
/// * We need to be intimately knowledgeable in how the login feature works so that we can assert
/// on how its state changes and how its effects feed data back into the system.
/// * If the login feature were to change its logic we may get test failures here even though the
/// logic we are acutally trying to test doesn't really care about those changes.
/// * This test is very long, and so if there are other similar but slightly different flows we
/// want to test we will be tempted to copy-and-paste the whole thing, leading to lots of
/// duplicated, fragile tests.
///
/// Non-exhaustive testing allows us to test the high-level flow that we are concerned with, that of
/// login causing the selected tab to switch to activity, without having to worry about what is
/// happening inside the login feature. To do this, we can turn off ``TestStore/exhaustivity`` in
/// the test store, and then just assert on what we are interested in:
///
/// ```swift
/// let store = TestStore(
///   initialState: App.State(),
///   reducer: App()
/// )
/// store.exhaustivity = .none // ⬅️
///
/// await store.send(.login(.submitButtonTapped))
/// await store.receive(.login(.delegate(.didLogin))) {
///   $0.selectedTab = .activity
/// }
/// ```
///
/// In particular, we did not assert on how the login's state changed or how the login's effects fed
/// data back into the system. We just assert that when the "Submit" button is tapped that
/// eventually we get the `didLogin` delegate action and that causes the selected tab to flip to
/// activity. Now the login feature is free to make any change it wants to make without affecting
/// this integration test.
///
/// Using ``Exhaustivity/none`` for ``TestStore/exhaustivity`` causes all un-asserted changes to
/// pass without any notification. If you would like to see what test failures are being supressed
/// without actually causing a failure, you can use ``Exhaustivity/partial``:
///
/// ```swift
/// let store = TestStore(
///   initialState: App.State(),
///   reducer: App()
/// )
/// store.exhaustivity = .partial // ⬅️
///
/// await store.send(.login(.submitButtonTapped))
/// await store.receive(.login(.delegate(.didLogin))) {
///   $0.selectedTab = .profile
/// }
/// ```
///
/// When this is run you will get grey, informational boxes on each assertion where some change
/// wasn't fully asserted on:
///
/// ```
/// ◽️ A state change does not match expectation: …
///
///      App.State(
///        authenticatedTab: .loggedOut(
///          Login.State(
///    −       isLoading: false
///    +       isLoading: true,
///            …
///          )
///        )
///      )
///
///    (Expected: −, Actual: +)
///
/// ◽️ Skipped receiving .login(.loginResponse(.success))
///
/// ◽️ A state change does not match expectation: …
///
///      App.State(
///    −   authenticatedTab: .loggedOut(…)
///    +   authenticatedTab: .loggedIn(
///    +     Profile.State(…)
///    +   ),
///        …
///      )
///
///    (Expected: −, Actual: +)
/// ```
///
/// The test still passes, and none of these notifications are test failures. They just let you know
/// what things you are not explicitly asserting against, and can be useful to see when tracking
/// down bugs that happen in production but that aren't currently detected in tests.
open class TestStore<State, Action, ScopedState, ScopedAction, Environment> {

  /// The current dependencies.
  ///
  /// The dependencies define the execution context that your feature runs in. They can be
  /// modified throughout the test store's lifecycle in order to influence how your feature
  /// produces effects.
  ///
  /// Typically you will override certain dependencies immediately after constructing the test
  /// store. For example, if your feature need access to the current date and an API client to
  /// do its job, you can override those dependencies like so:
  ///
  /// ```swift
  /// let store = TestStore(…)
  ///
  /// store.dependencies.apiClient = .mock
  /// store.dependencies.date = .constant(Date(timeIntervalSinceReferenceDate: 1234567890))
  ///
  /// // Store assertions here
  /// ```
  ///
  /// You can also override dependencies in the middle of the test in order to simulate how the
  /// dependency changes as the user performs action. For example, to test the flow of an API
  /// request failing at first but then later succeeding, you can do the following:
  ///
  /// ```swift
  /// store.dependencies.apiClient = .failing
  ///
  /// // Store assertions with failing API client
  ///
  /// store.dependencies.apiClient = .mock
  ///
  /// // Store assertions with succeeding API client
  /// ```
  public var dependencies: DependencyValues {
    _read { yield self.reducer.dependencies }
    _modify { yield &self.reducer.dependencies }
  }

  /// The current exhaustivity level of the test store.
  public var exhaustivity: Exhaustivity = .exhaustive

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
  /// ``receive(_:timeout:_:file:line:)-8yd62``, it will equal the `inout` state passed to the
  /// closure.
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

        XCTFailHelper(
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
      XCTFailHelper(
        """
        The store received \(self.reducer.receivedActions.count) unexpected \
        action\(self.reducer.receivedActions.count == 1 ? "" : "s") after this one: …

        Unhandled actions: \(actions)
        """,
        file: self.file,
        line: self.line
      )
    }
    for effect in self.reducer.inFlightEffects {
      XCTFailHelper(
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
        file: effect.action.file,
        line: effect.action.line
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
      XCTFailHelper(
        """
        Must handle \(self.reducer.receivedActions.count) received \
        action\(self.reducer.receivedActions.count == 1 ? "" : "s") before sending an action: …

        Unhandled actions: \(actions)
        """,
        file: file,
        line: line
      )
    }

    switch self.exhaustivity {
    case .exhaustive:
      break
    case .partial:
      await self.skipReceivedActions(strict: false)
    case .none:
      self.reducer.receivedActions = []
    }

    let expectedState = self.toScopedState(self.state)
    let previousState = self.reducer.state
    let task = self.store
      .send(.init(origin: .send(self.fromScopedAction(action)), file: file, line: line))
    await self.reducer.effectDidSubscribe.stream.first(where: { _ in true })
    do {
      let currentState = self.state
      self.reducer.state = previousState
      defer { self.reducer.state = currentState }

      try self.expectedStateShouldMatch(
        expected: expectedState,
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
      XCTFailHelper(
        """
        Must handle \(self.reducer.receivedActions.count) received \
        action\(self.reducer.receivedActions.count == 1 ? "" : "s") before sending an action: …

        Unhandled actions: \(actions)
        """,
        file: file,
        line: line
      )
    }

    switch self.exhaustivity {
    case .exhaustive:
      break
    case .partial:
      self.skipReceivedActions(strict: false)
    case .none:
      self.reducer.receivedActions = []
    }

    let expectedState = self.toScopedState(self.state)
    let previousState = self.state
    let task = self.store
      .send(.init(origin: .send(self.fromScopedAction(action)), file: file, line: line))
    do {
      let currentState = self.state
      self.reducer.state = previousState
      defer { self.reducer.state = currentState }

      try self.expectedStateShouldMatch(
        expected: expectedState,
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
    expected: ScopedState,
    actual: ScopedState,
    modify: ((inout ScopedState) throws -> Void)? = nil,
    file: StaticString,
    line: UInt
  ) throws {
    let current = expected
    var expected = expected

    switch self.exhaustivity {
    case .exhaustive:
      var expectedWhenGivenPreviousState = expected
      if let modify = modify {
        try modify(&expectedWhenGivenPreviousState)
      }
      expected = expectedWhenGivenPreviousState

      if expectedWhenGivenPreviousState != actual {
        expectationFailure(expected: expectedWhenGivenPreviousState)
      } else {
        tryUnnecessaryModifyFailure()
      }

    case .none, .partial:
      var expectedWhenGivenActualState = actual
      if let modify = modify {
        try modify(&expectedWhenGivenActualState)
      }
      expected = expectedWhenGivenActualState

      if expectedWhenGivenActualState != actual {
        self.withExhaustivity(.exhaustive) {
          expectationFailure(expected: expectedWhenGivenActualState)
        }
      } else if self.exhaustivity.isPartial && expectedWhenGivenActualState == actual {
        var expectedWhenGivenPreviousState = current
        if let modify = modify {
          _XCTExpectFailure(strict: false) {
            do {
              try modify(&expectedWhenGivenPreviousState)
            } catch {
              XCTFail(
                "\(self.exhaustivity.prefix ?? "") Threw error: \(error)",
                file: file,
                line: line
              )
            }
          }
        }
        expected = expectedWhenGivenPreviousState
        if expectedWhenGivenPreviousState != actual {
          expectationFailure(expected: expectedWhenGivenPreviousState)
        } else {
          tryUnnecessaryModifyFailure()
        }
      } else {
        tryUnnecessaryModifyFailure()
      }
    }

    func expectationFailure(expected: ScopedState) {
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
      XCTFailHelper(
        """
        \(messageHeading): …

        \(difference)
        """,
        file: file,
        line: line
      )
    }

    func tryUnnecessaryModifyFailure() {
      guard expected == current && modify != nil
      else { return }

      XCTFailHelper(
        """
        Expected state to change, but no change occurred.

        The trailing closure made no observable modifications to state. If no change to state is \
        expected, omit the trailing closure.
        """,
        file: file,
        line: line
      )
    }
  }

  private func withExhaustivity(_ exhaustivity: Exhaustivity, operation: () -> Void) {
    let previous = self.exhaustivity
    self.exhaustivity = exhaustivity
    operation()
    self.exhaustivity = previous
  }
}

extension TestStore where ScopedState: Equatable, Action: Equatable {
  // TODO: support receive with case path?
  // TODO: support skipReceivedActions(CasePath)

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
        file: file,
        line: line
      )
      return
    }

    if self.exhaustivity != .exhaustive {
      guard self.reducer.receivedActions.contains(where: { $0.action == expectedAction }) else {
        XCTFail(
          """
          Expected to receive an action \(expectedAction), but didn't get one.
          """,
          file: file, line: line
        )
        return
      }

      while let receivedAction = self.reducer.receivedActions.first,
        receivedAction.action != expectedAction
      {
        XCTFailHelper(  // TODO: Finesse copy
          """
          Skipped assertions: …
          Skipped receiving \(receivedAction.action)
          """,
          file: file,
          line: line
        )
        self.withExhaustivity(.none) {
          self.receive(receivedAction.action)
        }
      }
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

      XCTFailHelper(
        """
        Received unexpected action: …

        \(difference)
        """,
        file: file,
        line: line
      )
    }
    let expectedState = self.toScopedState(self.state)
    do {
      try self.expectedStateShouldMatch(
        expected: expectedState,
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

            If you are not yet using a scheduler, or can not use a scheduler, \(timeoutMessage).
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

  /// Clears the queue of received actions from effects.
  ///
  /// Can be handy if you are writing an exhaustive test for a particular part of your feature,
  /// but you don't want to explicitly deal with all of the received actions:
  ///
  /// ```swift
  /// let store = TestStore(…)
  ///
  /// await store.send(.buttonTapped) {
  ///   // Assert on how state changed
  /// }
  /// await store.receive(.response(…)) {
  ///   // Assert on how state changed
  /// }
  ///
  /// // Make it explicit you do not want to assert on any other received actions.
  /// store.flushReceivedActions()
  /// ```
  ///
  /// - Parameters:
  ///   - strict: When true and there are no received actions to flush, a test failure will be
  ///   raised.
  @MainActor
  public func skipReceivedActions(
    strict: Bool = true,
    file: StaticString = #file,
    line: UInt = #line
  ) async {
    await Task.megaYield()
    _ = { self.skipReceivedActions(strict: strict, file: file, line: line) }()
  }

  public func skipReceivedActions(
    strict: Bool = true,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    if strict && self.reducer.receivedActions.isEmpty {
      XCTFail("There were no received actions to skip.")
      return
    }
    guard !self.reducer.receivedActions.isEmpty
    else { return }
    var actions = ""
    if self.reducer.receivedActions.count == 1 {
      customDump(self.reducer.receivedActions[0].action, to: &actions)
    } else {
      customDump(self.reducer.receivedActions.map { $0.action }, to: &actions)
    }
    XCTFailHelper(
      """
      \(self.reducer.receivedActions.count) received action\
      \(self.reducer.receivedActions.count == 1 ? " was" : "s were") flushed:

      \(actions)
      """,
      overrideExhaustivity: self.exhaustivity == .none
        ? self.exhaustivity
        : .partial(prefix: self.exhaustivity.prefix),
      file: file,
      line: line
    )
    self.reducer.state = self.reducer.receivedActions.last!.state
    self.reducer.receivedActions = []
  }

  /// Cancels any currently inflight effects.
  ///
  /// Can be handy if you are writing an exhaustive test for a particular part of your feature,
  /// but you don't want to explicitly deal with all effects:
  ///
  /// ```swift
  /// let store = TestStore(…)
  ///
  /// await store.send(.buttonTapped) {
  ///   // Assert on how state changed
  /// }
  /// await store.receive(.response(…)) {
  ///   // Assert on how state changed
  /// }
  ///
  /// // Make it explicit you do not want to assert on how any other effects behave.
  /// store.cancelInFlightEffects()
  /// ```
  ///
  /// - Parameters:
  ///   - strict: When true and there are no inflight actions to cancel, a test failure will be
  ///   raised.
  public func skipInFlightEffects(
    strict: Bool = true,
    file: StaticString = #file,
    line: UInt = #line
  ) async {
    await Task.megaYield()
    _ = { self.skipInFlightEffects(strict: strict, file: file, line: line) }()
  }

  func skipInFlightEffects(
    strict: Bool = true,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    if strict && self.reducer.inFlightEffects.isEmpty {
      XCTFail("There were no in-flight effects to skip.")
      return
    }
    guard !self.reducer.inFlightEffects.isEmpty
    else { return }

    var actions = ""
    if self.reducer.inFlightEffects.count == 1 {
      customDump(self.reducer.inFlightEffects.first!.action.origin.action, to: &actions)
    } else {
      customDump(self.reducer.inFlightEffects.map { $0.action.origin.action }, to: &actions)
    }

    XCTFailHelper(
      """
      \(self.reducer.inFlightEffects.count) in-flight effect\
      \(self.reducer.inFlightEffects.count == 1 ? " was" : "s were") cancelled, originating from:

      \(actions)
      """,
      overrideExhaustivity: self.exhaustivity == .none
        ? self.exhaustivity
        : .partial(prefix: self.exhaustivity.prefix),
      file: file,
      line: line
    )

    for effect in self.reducer.inFlightEffects {
      _ = Effect<Never, Never>.cancel(id: effect.id).sink { _ in }
    }
    self.reducer.inFlightEffects = []
  }

  private func XCTFailHelper(
    _ message: String = "",
    overrideExhaustivity exhaustivity: Exhaustivity? = nil,
    file: StaticString,
    line: UInt
  ) {
    let exhaustivity = exhaustivity ?? self.exhaustivity
    switch exhaustivity {
    case .exhaustive:
      XCTFail(message, file: file, line: line)
    case let .partial(prefix: prefix):
      _XCTExpectFailure {
        XCTFail((prefix ?? "") + message, file: file, line: line)
      }
    case .none:
      break
    }
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
/// await mainQueue.advance(by: .seconds(1))
/// await store.receive(.timerTick) { $0.elapsed = 1 }
///
/// // Wait for cleanup effects to finish before completing the test
/// await store.send(.stopTimerButtonTapped).finish()
/// ```
///
/// See ``TestStore/finish(timeout:file:line:)-7pmv3`` for the ability to await all in-flight
/// effects in the test store.
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
  ///
  /// This can be handy when a feature needs to start a long-living effect when the feature appears,
  /// but cancellation of that effect is handled by the parent when the feature disappears. Such
  /// a feature is difficult to exhaustively test in isolation beceause there is no action in its
  /// domain that cancels the effect:
  ///
  /// ```swift
  /// let store = TestStore(...)
  ///
  /// let onAppearTask = await store.send(.onAppear)
  /// // Assert what is happening in the feature
  ///
  /// await onAppearTask.cancel() // ✅ Cancel the task to simulate the feature disappearing.
  /// ```
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
      let effect = LongLivingEffect(action: action)
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
    let action: TestAction

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
      case receive(Action)
      case send(Action)
      fileprivate var action: Action {
        switch self {
        case let .receive(action), let .send(action):
          return action
        }
      }
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

/// The level of exhaustivity for the test store.
public enum Exhaustivity: Equatable {
  /// Full exhaustivity, which means you must explicitly assert on how all state changes and all
  /// received actions from effects.
  case exhaustive
  /// No exhaustivity, which means you can assert on any subset of state changes and any subset
  /// of received actions from effects.
  case none
  /// Partial exhaustivity, which behaves exactly like ``none``, except any state not asserted
  /// on or receive actions skipped will be reported in a grey informational box next to the
  /// assertion. This is handy for when you want non-exhaustivity but you still want to know
  /// what all you are missing from your assertions.
  case partial(prefix: String? = "Partial assertions skipped. …\n\n")

  public static let partial = partial(prefix: "Partial assertions skipped. …\n\n")
  fileprivate var isPartial: Bool {
    guard case .partial = self else {
      return false
    }
    return true
  }
  fileprivate var prefix: String? {
    guard case let .partial(prefix: prefix) = self else {
      return nil
    }
    return prefix
  }
}

private func _XCTExpectFailure(
  _ failureReason: String? = nil,
  strict: Bool = true,
  failingBlock: () -> Void
) {
  guard
    let XCTExpectedFailureOptions = NSClassFromString("XCTExpectedFailureOptions")
      as Any as? NSObjectProtocol,
    let options = strict
      ? XCTExpectedFailureOptions
        .perform(NSSelectorFromString("alloc"))?.takeUnretainedValue()
        .perform(NSSelectorFromString("init"))?.takeUnretainedValue()
      : XCTExpectedFailureOptions
        .perform(NSSelectorFromString("nonStrictOptions"))?.takeUnretainedValue()
  else { return }

  let XCTExpectFailureWithOptionsInBlock = unsafeBitCast(
    dlsym(dlopen(nil, RTLD_LAZY), "XCTExpectFailureWithOptionsInBlock"),
    to: (@convention(c) (String?, AnyObject, () -> Void) -> Void).self
  )

  XCTExpectFailureWithOptionsInBlock(failureReason, options, failingBlock)
}
