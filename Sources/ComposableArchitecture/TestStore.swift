@_spi(Internals) import CasePaths
import Combine
import ConcurrencyExtras
import CustomDump
import Foundation
import XCTestDynamicOverlay

/// A testable runtime for a reducer.
///
/// This object aids in writing expressive and exhaustive tests for features built in the
/// Composable Architecture. It allows you to send a sequence of actions to the store, and each step
/// of the way you must assert exactly how state changed, and how effect emissions were fed back
/// into the system.
///
/// See the dedicated <doc:Testing> article for detailed information on testing.
///
/// ## Exhaustive testing
///
/// By default, ``TestStore`` requires you to exhaustively prove how your feature evolves from
/// sending use actions and receiving actions from effects. There are multiple ways the test store
/// forces you to do this:
///
///   * After each action is sent you must describe precisely how the state changed from before the
///     action was sent to after it was sent.
///
///     If even the smallest piece of data differs the test will fail. This guarantees that you are
///     proving you know precisely how the state of the system changes.
///
///   * Sending an action can sometimes cause an effect to be executed, and if that effect sends an
///     action back into the system, you **must** explicitly assert that you expect to receive that
///     action from the effect, _and_ you must assert how state changed as a result.
///
///     If you try to send another action before you have handled all effect actions, the test will
///     fail. This guarantees that you do not accidentally forget about an effect action, and that
///     the sequence of steps you are describing will mimic how the application behaves in reality.
///
///   * All effects must complete by the time the test case has finished running, and all effect
///     actions must be asserted on.
///
///     If at the end of the assertion there is still an in-flight effect running or an unreceived
///     action, the assertion will fail. This helps exhaustively prove that you know what effects
///     are in flight and forces you to prove that effects will not cause any future changes to your
///     state.
///
/// For example, given a simple counter reducer:
///
/// ```swift
/// @Reducer
/// struct Counter {
///   struct State: Equatable {
///     var count = 0
///   }
///
///   enum Action {
///     case decrementButtonTapped
///     case incrementButtonTapped
///   }
///
///   var body: some Reducer<State, Action> {
///     Reduce { state, action in
///       switch action {
///       case .decrementButtonTapped:
///         state.count -= 1
///         return .none
///
///       case .incrementButtonTapped:
///         state.count += 1
///         return .none
///       }
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
///       // Given: a counter state of 0
///       initialState: Counter.State(count: 0),
///     ) {
///       Counter()
///     }
///
///     // When: the increment button is tapped
///     await store.send(.incrementButtonTapped) {
///       // Then: the count should be 1
///       $0.count = 1
///     }
///   }
/// }
/// ```
///
/// Note that in the trailing closure of `.send(.incrementButtonTapped)` we are given a single
/// mutable value of the state before the action was sent, and it is our job to mutate the value to
/// match the state after the action was sent. In this case the `count` field changes to `1`.
///
/// If the change made in the closure does not reflect reality, you will get a test failure with a
/// nicely formatted failure message letting you know exactly what went wrong:
///
/// ```swift
/// await store.send(.incrementButtonTapped) {
///   $0.count = 42
/// }
/// ```
///
/// > ❌ Failure: A state change does not match expectation: …
/// >
/// > ```diff
/// >  TestStoreFailureTests.State(
/// > -   count: 42
/// > +   count: 1
/// >  )
/// > ```
/// >
/// > (Expected: −, Actual: +)
///
/// For a more complex example, consider the following bare-bones search feature that uses a clock
/// and cancel token to debounce requests:
///
/// ```swift
/// @Reducer
/// struct Search {
///   struct State: Equatable {
///     var query = ""
///     var results: [String] = []
///   }
///
///   enum Action {
///     case queryChanged(String)
///     case searchResponse(Result<[String], Error>)
///   }
///
///   @Dependency(\.apiClient) var apiClient
///   @Dependency(\.continuousClock) var clock
///   private enum CancelID { case search }
///
///   var body: some Reducer<State, Action> {
///     Reduce { state, action in
///       switch action {
///       case let .queryChanged(query):
///         state.query = query
///         return .run { send in
///           try await self.clock.sleep(for: 0.5)
///
///           await send(.searchResponse(Result { try await self.apiClient.search(query) }))
///         }
///         .cancellable(id: CancelID.search, cancelInFlight: true)
///
///       case let .searchResponse(.success(results)):
///         state.results = results
///         return .none
///
///       case .searchResponse(.failure):
///         // Do error handling here.
///         return .none
///       }
///     }
///   }
/// }
/// ```
///
/// It can be fully tested by overriding the `apiClient` and `continuousClock` dependencies with
/// values that are fully controlled and deterministic:
///
/// ```swift
/// // Create a test clock to control the timing of effects
/// let clock = TestClock()
///
/// let store = TestStore(initialState: Search.State()) {
///   Search()
/// } withDependencies: {
///   // Override the clock dependency with the test clock
///   $0.continuousClock = clock
///
///   // Simulate a search response with one item
///   $0.apiClient.search = { _ in
///     ["Composable Architecture"]
///   }
/// )
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
/// await store.receive(\.searchResponse.success) {
///   $0.results = ["Composable Architecture"]
/// }
/// ```
///
/// This test is proving that when the search query changes some search responses are delivered and
/// state updates accordingly.
///
/// If we did not assert that the `searchResponse` action was received, we would get the following
/// test failure:
///
/// > ❌ Failure: The store received 1 unexpected action after this one: …
/// >
/// > ```
/// > Unhandled actions: [
/// >   [0]: Search.Action.searchResponse
/// > ]
/// > ```
///
/// This helpfully lets us know that we have no asserted on everything that happened in the feature,
/// which could be hiding a bug from us.
///
/// Or if we had sent another action before handling the effect's action we would have also gotten
/// a test failure:
///
/// > ❌ Failure: Must handle 1 received action before sending an action: …
/// >
/// > ```
/// > Unhandled actions: [
/// >   [0]: Search.Action.searchResponse
/// > ]
/// > ```
///
/// All of these types of failures help you prove that you know exactly how your feature evolves as
/// actions are sent into the system. If the library did not produce a test failure in these
/// situations it could be hiding subtle bugs in your code. For example, when the user clears the
/// search query you probably expect that the results are cleared and no search request is executed
/// since there is no query. This can be done like so:
///
/// ```swift
/// await store.send(.queryChanged("")) {
///   $0.query = ""
///   $0.results = []
/// }
///
/// // No need to perform `store.receive` since we do not expect a search
/// // effect to execute.
/// ```
///
/// But, if in the future a bug is introduced causing a search request to be executed even when the
/// query is empty, you will get a test failure because a new effect is being created that is not
/// being asserted on. This is the power of exhaustive testing.
///
/// ## Non-exhaustive testing
///
/// While exhaustive testing can be powerful, it can also be a nuisance, especially when testing how
/// many features integrate together. This is why sometimes you may want to selectively test in a
/// non-exhaustive style.
///
/// > Tip: The concept of "non-exhaustive test store" was first introduced by
/// [Krzysztof Zabłocki][merowing.info] in a [blog post][exhaustive-testing-in-tca] and
/// [conference talk][Composable-Architecture-at-Scale], and then later became integrated into the
/// core library.
///
/// Test stores are exhaustive by default, which means you must assert on every state change, and
/// how ever effect feeds data back into the system, and you must make sure that all effects
/// complete before the test is finished. To turn off exhaustivity you can set ``exhaustivity``
/// to ``Exhaustivity/off``. When that is done the ``TestStore``'s behavior changes:
///
///   * The trailing closures of ``send(_:assert:file:line:)-2co21`` and
///     ``receive(_:timeout:assert:file:line:)-6325h`` no longer need to assert on all state
///     changes. They can assert on any subset of changes, and only if they make an incorrect
///     mutation will a test failure be reported.
///   * The ``send(_:assert:file:line:)-2co21`` and ``receive(_:timeout:assert:file:line:)-6325h``
///     methods are allowed to be called even when actions have been received from effects that have
///     not been asserted on yet. Any pending actions will be cleared.
///   * Tests are allowed to finish with unasserted, received actions and in-flight effects. No test
///     failures will be reported.
///
/// Non-exhaustive stores can be configured to report skipped assertions by configuring
/// ``Exhaustivity/off(showSkippedAssertions:)``. When set to `true` the test store will have the
/// added behavior that any unasserted change causes a grey, informational box to appear next to
/// each assertion detailing the changes that were not asserted against. This allows you to see what
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
/// let store = TestStore(initialState: App.State()) {
///   App()
/// }
///
/// // 1️⃣ Emulate user tapping on submit button.
/// //    (You can use case key path syntax to send actions to deeply nested features.)
/// await store.send(\.login.submitButtonTapped) {
///   // 2️⃣ Assert how all state changes in the login feature
///   $0.login?.isLoading = true
///   …
/// }
///
/// // 3️⃣ Login feature performs API request to login, and
/// //    sends response back into system.
/// await store.receive(\.login.loginResponse.success) {
/// // 4️⃣ Assert how all state changes in the login feature
///   $0.login?.isLoading = false
///   …
/// }
///
/// // 5️⃣ Login feature sends a delegate action to let parent
/// //    feature know it has successfully logged in.
/// await store.receive(\.login.delegate.didLogin) {
/// // 6️⃣ Assert how all of app state changes due to that action.
///   $0.authenticatedTab = .loggedIn(
///     Profile.State(...)
///   )
///   …
///   // 7️⃣ *Finally* assert that the selected tab switches to activity.
///   $0.selectedTab = .activity
/// }
/// ```
///
/// Doing this with exhaustive testing is verbose, and there are a few problems with this:
///
///   * We need to be intimately knowledgeable in how the login feature works so that we can assert
///     on how its state changes and how its effects feed data back into the system.
///   * If the login feature were to change its logic we may get test failures here even though the
///     logic we are actually trying to test doesn't really care about those changes.
///   * This test is very long, and so if there are other similar but slightly different flows we
///     want to test we will be tempted to copy-and-paste the whole thing, leading to lots of
///     duplicated, fragile tests.
///
/// Non-exhaustive testing allows us to test the high-level flow that we are concerned with, that of
/// login causing the selected tab to switch to activity, without having to worry about what is
/// happening inside the login feature. To do this, we can turn off ``TestStore/exhaustivity`` in
/// the test store, and then just assert on what we are interested in:
///
/// ```swift
/// let store = TestStore(App.State()) {
///   App()
/// }
/// store.exhaustivity = .off  // ⬅️
///
/// await store.send(\.login.submitButtonTapped)
/// await store.receive(\.login.delegate.didLogin) {
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
/// Using ``Exhaustivity/off`` for ``TestStore/exhaustivity`` causes all un-asserted changes to pass
/// without any notification. If you would like to see what test failures are being suppressed
/// without actually causing a failure, you can use ``Exhaustivity/off(showSkippedAssertions:)``:
///
/// ```swift
/// let store = TestStore(initialState: App.State()) {
///   App()
/// }
/// store.exhaustivity = .off(showSkippedAssertions: true)  // ⬅️
///
/// await store.send(\.login.submitButtonTapped)
/// await store.receive(\.login.delegate.didLogin) {
///   $0.selectedTab = .profile
/// }
/// ```
///
/// When this is run you will get grey, informational boxes on each assertion where some change
/// wasn't fully asserted on:
///
/// > ◽️ Expected failure: A state change does not match expectation: …
/// >
/// > ```diff
/// >   App.State(
/// >     authenticatedTab: .loggedOut(
/// >       Login.State(
/// > -       isLoading: false
/// > +       isLoading: true,
/// >         …
/// >       )
/// >     )
/// >   )
/// > ```
/// >
/// > Skipped receiving .login(.loginResponse(.success))
/// >
/// > A state change does not match expectation: …
/// >
/// > ```diff
/// >   App.State(
/// > -   authenticatedTab: .loggedOut(…)
/// > +   authenticatedTab: .loggedIn(
/// > +     Profile.State(…)
/// > +   ),
/// >     …
/// >   )
/// > ```
/// >
/// > (Expected: −, Actual: +)
///
/// The test still passes, and none of these notifications are test failures. They just let you know
/// what things you are not explicitly asserting against, and can be useful to see when tracking
/// down bugs that happen in production but that aren't currently detected in tests.
///
/// [merowing.info]: https://www.merowing.info
/// [exhaustive-testing-in-tca]: https://www.merowing.info/exhaustive-testing-in-tca/
/// [Composable-Architecture-at-Scale]: https://vimeo.com/751173570
public final class TestStore<State, Action> {

  /// The current dependencies of the test store.
  ///
  /// The dependencies define the execution context that your feature runs in. They can be modified
  /// throughout the test store's lifecycle in order to influence how your feature produces effects.
  ///
  /// Typically you will override certain dependencies immediately after constructing the test
  /// store. For example, if your feature need access to the current date and an API client to do
  /// its job, you can override those dependencies like so:
  ///
  /// ```swift
  /// let store = TestStore(/* ... */) {
  ///   $0.apiClient = .mock
  ///   $0.date = .constant(Date(timeIntervalSinceReferenceDate: 1234567890))
  /// }
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
  /// store.send(.buttonTapped) { /* ... */ }
  /// store.receive(\.searchResponse.failure) { /* ... */ }
  ///
  /// store.dependencies.apiClient = .mock
  ///
  /// store.send(.buttonTapped) { /* ... */ }
  /// store.receive(\.searchResponse.success) { /* ... */ }
  /// ```
  public var dependencies: DependencyValues {
    _read { yield self.reducer.dependencies }
    _modify { yield &self.reducer.dependencies }
  }

  /// The current exhaustivity level of the test store.
  public var exhaustivity: Exhaustivity = .on

  /// Serializes all async work to the main thread for the lifetime of the test store.
  public var useMainSerialExecutor: Bool {
    get { uncheckedUseMainSerialExecutor }
    set { uncheckedUseMainSerialExecutor = newValue }
  }
  private let originalUseMainSerialExecutor = uncheckedUseMainSerialExecutor

  /// The current state of the test store.
  ///
  /// When read from a trailing closure assertion in ``send(_:assert:file:line:)-2co21`` or
  /// ``receive(_:timeout:assert:file:line:)-6325h``, it will equal the `inout` state passed to the
  /// closure.
  public var state: State {
    self.reducer.state
  }

  /// The default timeout used in all methods that take an optional timeout.
  ///
  /// This is the default timeout used in all methods that take an optional timeout, such as
  /// ``receive(_:timeout:assert:file:line:)-6325h`` and ``finish(timeout:file:line:)-53gi5``.
  public var timeout: UInt64

  private let file: StaticString
  private let line: UInt
  let reducer: TestReducer<State, Action>
  private let sharedChangeTracker: SharedChangeTracker
  private let store: Store<State, TestReducer<State, Action>.TestAction>

  /// Creates a test store with an initial state and a reducer powering its runtime.
  ///
  /// See <doc:Testing> and the documentation of ``TestStore`` for more information on how to best
  /// use a test store.
  ///
  /// - Parameters:
  ///   - initialState: The state the feature starts in.
  ///   - reducer: The reducer that powers the runtime of the feature. Unlike
  ///     ``Store/init(initialState:reducer:withDependencies:)``, this is _not_ a builder closure
  ///     due to a [Swift bug](https://github.com/apple/swift/issues/72399) that is more likely to
  ///     affect test store initialization. If you must compose multiple reducers in this closure,
  ///     wrap them in ``CombineReducers``.
  ///   - prepareDependencies: A closure that can be used to override dependencies that will be
  ///     accessed during the test. These dependencies will be used when producing the initial
  ///     state.
  public init<R: Reducer>(
    initialState: @autoclosure () -> State,
    reducer: () -> R,
    withDependencies prepareDependencies: (inout DependencyValues) -> Void = { _ in
    },
    file: StaticString = #file,
    line: UInt = #line
  )
  where State: Equatable, R.State == State, R.Action == Action {
    let sharedChangeTracker = SharedChangeTracker()
    let reducer = XCTFailContext.$current.withValue(XCTFailContext(file: file, line: line)) {
      Dependencies.withDependencies {
        prepareDependencies(&$0)
        $0.sharedChangeTrackers.insert(sharedChangeTracker)
      } operation: {
        TestReducer(Reduce(reducer()), initialState: initialState())
      }
    }
    self.file = file
    self.line = line
    self.reducer = reducer
    self.store = Store(initialState: reducer.state) { reducer }
    self.timeout = 1 * NSEC_PER_SEC
    self.sharedChangeTracker = sharedChangeTracker
    self.useMainSerialExecutor = true
  }

  // NB: Only needed until Xcode ships a macOS SDK that uses the 5.7 standard library.
  // See: https://forums.swift.org/t/xcode-14-rc-cannot-specialize-protocol-type/60171/15
  #if (canImport(RegexBuilder) || !os(macOS) && !targetEnvironment(macCatalyst))
    /// Suspends until all in-flight effects have finished, or until it times out.
    ///
    /// Can be used to assert that all effects have finished.
    ///
    /// - Parameter duration: The amount of time to wait before asserting.
    @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
    @MainActor
    public func finish(
      timeout duration: Duration,
      file: StaticString = #file,
      line: UInt = #line
    ) async {
      await self.finish(timeout: duration.nanoseconds, file: file, line: line)
    }
  #endif

  /// Suspends until all in-flight effects have finished, or until it times out.
  ///
  /// Can be used to assert that all effects have finished.
  ///
  /// > Important: `TestStore.finish()` should only be called once per test store, at the end of the
  /// > test. Interacting with a finished test store is undefined.
  ///
  /// - Parameter nanoseconds: The amount of time to wait before asserting.
  @_disfavoredOverload
  @MainActor
  public func finish(
    timeout nanoseconds: UInt64? = nil,
    file: StaticString = #file,
    line: UInt = #line
  ) async {
    Task.cancel(id: OnFirstAppearID())

    let nanoseconds = nanoseconds ?? self.timeout
    let start = DispatchTime.now().uptimeNanoseconds
    await Task.megaYield()
    while !self.reducer.inFlightEffects.isEmpty {
      guard start.distance(to: DispatchTime.now().uptimeNanoseconds) < nanoseconds
      else {
        let timeoutMessage =
          nanoseconds != self.timeout
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
    uncheckedUseMainSerialExecutor = self.originalUseMainSerialExecutor
  }

  func completed() {
    if !self.reducer.receivedActions.isEmpty {
      let actions = self.reducer.receivedActions
        .map(\.action)
        .map { "    • " + debugCaseOutput($0, abbreviated: true) }
        .joined(separator: "\n")
      XCTFailHelper(
        """
        The store received \(self.reducer.receivedActions.count) unexpected \
        action\(self.reducer.receivedActions.count == 1 ? "" : "s") by the end of this test: …

          Unhandled actions:
        \(actions)
        """,
        file: self.file,
        line: self.line
      )
    }
    Task.cancel(id: OnFirstAppearID())
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
    // NB: This existential opening can go away if we can constrain 'State: Equatable' at the
    //     'TestStore' level, but for some reason this breaks DocC.
    if self.sharedChangeTracker.hasChanges, let stateType = State.self as? any Equatable.Type {
      func open<EquatableState: Equatable>(_: EquatableState.Type) {
        let store = self as! TestStore<EquatableState, Action>
        try? store.expectedStateShouldMatch(
          preamble: "Test store completed before asserting against changes to shared state",
          postamble: """
            Invoke "TestStore.assert" at the end of this test to assert against changes to shared \
            state.
            """,
          expected: store.state,
          actual: store.state,
          updateStateToExpectedResult: nil,
          skipUnnecessaryModifyFailure: true,
          file: store.file,
          line: store.line
        )
      }
      open(stateType)
    }
  }

  /// Overrides the store's dependencies for a given operation.
  ///
  /// - Parameters:
  ///   - updateValuesForOperation: A closure for updating the store's dependency values for the
  ///     duration of the operation.
  ///   - operation: The operation.
  public func withDependencies<R>(
    _ updateValuesForOperation: (_ dependencies: inout DependencyValues) throws -> Void,
    operation: () throws -> R
  ) rethrows -> R {
    let previous = self.dependencies
    defer { self.dependencies = previous }
    try updateValuesForOperation(&self.dependencies)
    return try operation()
  }

  /// Overrides the store's dependencies for a given operation.
  ///
  /// - Parameters:
  ///   - updateValuesForOperation: A closure for updating the store's dependency values for the
  ///     duration of the operation.
  ///   - operation: The operation.
  @MainActor
  public func withDependencies<R>(
    _ updateValuesForOperation: (_ dependencies: inout DependencyValues) async throws -> Void,
    operation: @MainActor () async throws -> R
  ) async rethrows -> R {
    let previous = self.dependencies
    defer { self.dependencies = previous }
    try await updateValuesForOperation(&self.dependencies)
    return try await operation()
  }

  /// Overrides the store's exhaustivity for a given operation.
  ///
  /// - Parameters:
  ///   - exhaustivity: The exhaustivity.
  ///   - operation: The operation.
  public func withExhaustivity<R>(
    _ exhaustivity: Exhaustivity,
    operation: () throws -> R
  ) rethrows -> R {
    let previous = self.exhaustivity
    defer { self.exhaustivity = previous }
    self.exhaustivity = exhaustivity
    return try operation()
  }

  /// Overrides the store's exhaustivity for a given operation.
  ///
  /// - Parameters:
  ///   - exhaustivity: The exhaustivity.
  ///   - operation: The operation.
  @MainActor
  public func withExhaustivity<R>(
    _ exhaustivity: Exhaustivity,
    operation: @MainActor () async throws -> R
  ) async rethrows -> R {
    let previous = self.exhaustivity
    defer { self.exhaustivity = previous }
    self.exhaustivity = exhaustivity
    return try await operation()
  }
}

/// A convenience type alias for referring to a test store of a given reducer's domain.
///
/// Instead of specifying two generics:
///
/// ```swift
/// let testStore: TestStore<Feature.State, Feature.Action>
/// ```
///
/// You can specify a single generic:
///
/// ```swift
/// let testStore: TestStoreOf<Feature>
/// ```
public typealias TestStoreOf<R: Reducer> = TestStore<R.State, R.Action>

extension TestStore where State: Equatable {
  /// Sends an action to the store and asserts when state changes.
  ///
  /// To assert on how state changes you can provide a trailing closure, and that closure is handed
  /// a mutable variable that represents the feature's state _before_ the action was sent. You need
  /// to mutate that variable so that it is equal to the feature's state _after_ the action is sent:
  ///
  /// ```swift
  /// await store.send(.incrementButtonTapped) {
  ///   $0.count = 1
  /// }
  /// await store.send(.decrementButtonTapped) {
  ///   $0.count = 0
  /// }
  /// ```
  ///
  /// This method suspends in order to allow any effects to start. For example, if you track an
  /// analytics event in an effect when an action is sent, you can assert on that behavior
  /// immediately after awaiting `store.send`:
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
  ///   let store = TestStore(initialState: Feature.State()) {
  ///     Feature()
  ///   } withDependencies {
  ///     $0.analytics = analytics
  ///   }
  ///
  ///   await store.send(.buttonTapped)
  ///
  ///   await events.withValue { XCTAssertEqual($0, ["Button Tapped"]) }
  /// }
  /// ```
  ///
  /// This method suspends only for the duration until the effect _starts_ from sending the action.
  /// It does _not_ suspend for the duration of the effect.
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
  /// let store = TestStore(/* ... */)
  ///
  /// // Emulate the view appearing
  /// let task = await store.send(.task)
  ///
  /// // Assertions
  ///
  /// // Emulate the view disappearing
  /// await task.cancel()
  /// ```
  ///
  /// - Parameters:
  ///   - action: An action.
  ///   - updateStateToExpectedResult: A closure that asserts state changed by sending the action to
  ///     the store. The mutable state sent to this closure must be modified to match the state of
  ///     the store after processing the given action. Do not provide a closure if no change is
  ///     expected.
  /// - Returns: A ``TestStoreTask`` that represents the lifecycle of the effect executed when
  ///   sending the action.
  @MainActor
  @discardableResult
  public func send(
    _ action: Action,
    assert updateStateToExpectedResult: ((_ state: inout State) throws -> Void)? = nil,
    file: StaticString = #file,
    line: UInt = #line
  ) async -> TestStoreTask {
    await XCTFailContext.$current.withValue(XCTFailContext(file: file, line: line)) {
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
      case .on:
        break
      case .off(showSkippedAssertions: true):
        await self.skipReceivedActions(strict: false)
      case .off(showSkippedAssertions: false):
        self.reducer.receivedActions = []
      }

      let expectedState = self.state
      let previousState = self.reducer.state
      let previousStackElementID = self.reducer.dependencies.stackElementID.incrementingCopy()
      let task = self.sharedChangeTracker.track {
        self.store.send(
          .init(origin: .send(action), file: file, line: line),
          originatingFrom: nil
        )
      }
      if uncheckedUseMainSerialExecutor {
        await Task.yield()
      } else {
        for await _ in self.reducer.effectDidSubscribe.stream {
          break
        }
      }
      do {
        let currentState = self.state
        let currentStackElementID = self.reducer.dependencies.stackElementID
        self.reducer.state = previousState
        self.reducer.dependencies.stackElementID = previousStackElementID
        defer {
          self.reducer.state = currentState
          self.reducer.dependencies.stackElementID = currentStackElementID
        }

        try self.expectedStateShouldMatch(
          expected: expectedState,
          actual: currentState,
          updateStateToExpectedResult: updateStateToExpectedResult,
          file: file,
          line: line
        )
      } catch {
        XCTFail("Threw error: \(error)", file: file, line: line)
      }
      // NB: Give concurrency runtime more time to kick off effects so users don't need to manually
      //     instrument their effects.
      await Task.megaYield(count: 20)
      return .init(rawValue: task, timeout: self.timeout)
    }
  }

  /// Assert against the current state of the store.
  ///
  /// The trailing closure provided is given a mutable argument that represents the current state,
  /// and you can provide any mutations you want to the state. If your mutations cause the argument
  /// to differ from the current state of the test store, a test failure will be triggered.
  ///
  /// This tool is most useful in non-exhaustive test stores (see
  /// <doc:Testing#Non-exhaustive-testing>), which allow you to assert on a subset of the things
  /// happening inside your features. For example, you can send an action in a child feature
  /// without asserting on how many changes in the system, and then tell the test store to
  /// ``finish(timeout:file:line:)-53gi5`` by executing all of its effects, and finally to
  /// ``skipReceivedActions(strict:file:line:)-a4ri`` to receive all actions. After that is done you
  /// can assert on the final state of the store:
  ///
  /// ```swift
  /// store.exhaustivity = .off
  /// await store.send(\.child.closeButtonTapped)
  /// await store.finish()
  /// await store.skipReceivedActions()
  /// store.assert {
  ///   $0.child = nil
  /// }
  /// ```
  ///
  /// > Note: This helper is only intended to be used with non-exhaustive test stores. It is not
  /// needed in exhaustive test stores since any assertion you may make inside the trailing closure
  /// has already been handled by a previous `send` or `receive`.
  ///
  /// - Parameters:
  ///   - updateStateToExpectedResult: A closure that asserts against the current state of the test
  ///   store.
  @MainActor
  public func assert(
    _ updateStateToExpectedResult: @escaping (_ state: inout State) throws -> Void,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    XCTFailContext.$current.withValue(XCTFailContext(file: file, line: line)) {
      let expectedState = self.state
      let currentState = self.reducer.state
      do {
        try self.expectedStateShouldMatch(
          expected: expectedState,
          actual: currentState,
          updateStateToExpectedResult: updateStateToExpectedResult,
          skipUnnecessaryModifyFailure: true,
          file: file,
          line: line
        )
      } catch {
        XCTFail("Threw error: \(error)", file: file, line: line)
      }
    }
  }

  private func expectedStateShouldMatch(
    preamble: String = "",
    postamble: String = "",
    expected: State,
    actual: State,
    updateStateToExpectedResult: ((inout State) throws -> Void)? = nil,
    skipUnnecessaryModifyFailure: Bool = false,
    file: StaticString,
    line: UInt
  ) throws {
    try self.sharedChangeTracker.assert {
      let skipUnnecessaryModifyFailure =
        skipUnnecessaryModifyFailure
        || self.sharedChangeTracker.hasChanges == true
      if self.exhaustivity != .on {
        self.sharedChangeTracker.resetChanges()
      }

      let current = expected
      var expected = expected

      let currentStackElementID = self.reducer.dependencies.stackElementID
      let copiedStackElementID = currentStackElementID.incrementingCopy()
      self.reducer.dependencies.stackElementID = copiedStackElementID
      defer {
        self.reducer.dependencies.stackElementID = currentStackElementID
      }

      let updateStateToExpectedResult = updateStateToExpectedResult.map { original in
        { (state: inout State) in
          try XCTModifyLocals.$isExhaustive.withValue(self.exhaustivity == .on) {
            try original(&state)
          }
        }
      }

      switch self.exhaustivity {
      case .on:
        var expectedWhenGivenPreviousState = expected
        if let updateStateToExpectedResult {
          try Dependencies.withDependencies {
            $0 = self.reducer.dependencies
            $0.sharedChangeTracker = self.sharedChangeTracker
          } operation: {
            try updateStateToExpectedResult(&expectedWhenGivenPreviousState)
          }
        }
        expected = expectedWhenGivenPreviousState

        if expectedWhenGivenPreviousState != actual {
          expectationFailure(expected: expectedWhenGivenPreviousState)
        } else {
          tryUnnecessaryModifyFailure()
        }

      case .off:
        var expectedWhenGivenActualState = actual
        if let updateStateToExpectedResult {
          try Dependencies.withDependencies {
            $0 = self.reducer.dependencies
            $0.sharedChangeTracker = self.sharedChangeTracker
          } operation: {
            try updateStateToExpectedResult(&expectedWhenGivenActualState)
          }
        }
        expected = expectedWhenGivenActualState

        if expectedWhenGivenActualState != actual {
          self.withExhaustivity(.on) {
            expectationFailure(expected: expectedWhenGivenActualState)
          }
        } else if self.exhaustivity == .off(showSkippedAssertions: true)
          && expectedWhenGivenActualState == actual
        {
          var expectedWhenGivenPreviousState = current
          if let updateStateToExpectedResult {
            XCTExpectFailure(strict: false) {
              do {
                try Dependencies.withDependencies {
                  $0 = self.reducer.dependencies
                  $0.sharedChangeTracker = self.sharedChangeTracker
                } operation: {
                  try updateStateToExpectedResult(&expectedWhenGivenPreviousState)
                }
              } catch {
                XCTFail(
                  """
                  Skipped assertions: …

                  Threw error: \(error)
                  """,
                  file: file,
                  line: line
                )
              }
            }
          }
          expected = expectedWhenGivenPreviousState
          if self.withExhaustivity(.on, operation: { expectedWhenGivenPreviousState != actual }) {
            expectationFailure(expected: expectedWhenGivenPreviousState)
          } else {
            tryUnnecessaryModifyFailure()
          }
        } else {
          tryUnnecessaryModifyFailure()
        }
      }

      func expectationFailure(expected: State) {
        let difference = self.withExhaustivity(.on) {
          diff(expected, actual, format: .proportional)
            .map { "\($0.indent(by: 4))\n\n(Expected: −, Actual: +)" }
              ?? """
              Expected:
              \(String(describing: expected).indent(by: 2))

              Actual:
              \(String(describing: actual).indent(by: 2))
              """
        }
        let messageHeading =
          !preamble.isEmpty
          ? preamble
          : updateStateToExpectedResult != nil
            ? "A state change does not match expectation"
            : "State was not expected to change, but a change occurred"
        XCTFailHelper(
          """
          \(messageHeading): …

          \(difference)\(postamble.isEmpty ? "" : "\n\n\(postamble)")
          """,
          file: file,
          line: line
        )
      }

      func tryUnnecessaryModifyFailure() {
        guard
          !skipUnnecessaryModifyFailure,
          expected == current,
          updateStateToExpectedResult != nil
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
      self.sharedChangeTracker.resetChanges()
    }
  }
}

extension TestStore where State: Equatable, Action: Equatable {
  private func _receive(
    _ expectedAction: Action,
    assert updateStateToExpectedResult: ((inout State) throws -> Void)? = nil,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    var expectedActionDump = ""
    customDump(expectedAction, to: &expectedActionDump, indent: 2)
    self.receiveAction(
      matching: { expectedAction == $0 },
      failureMessage: """
        Expected to receive the following action, but didn't: …

        \(expectedActionDump)
        """,
      unexpectedActionDescription: { receivedAction in
        TaskResultDebugging.$emitRuntimeWarnings.withValue(false) {
          diff(expectedAction, receivedAction, format: .proportional)
            .map { "\($0.indent(by: 4))\n\n(Expected: −, Received: +)" }
              ?? """
              Expected:
              \(String(describing: expectedAction).indent(by: 2))

              Received:
              \(String(describing: receivedAction).indent(by: 2))
              """
        }
      },
      updateStateToExpectedResult,
      file: file,
      line: line
    )
  }

  // NB: Only needed until Xcode ships a macOS SDK that uses the 5.7 standard library.
  // See: https://forums.swift.org/t/xcode-14-rc-cannot-specialize-protocol-type/60171/15
  #if (canImport(RegexBuilder) || !os(macOS) && !targetEnvironment(macCatalyst))
    /// Asserts an action was received from an effect and asserts how the state changes.
    ///
    /// When an effect is executed in your feature and sends an action back into the system, you can
    /// use this method to assert that fact, and further assert how state changes after the effect
    /// action is received:
    ///
    /// ```swift
    /// await store.send(.buttonTapped)
    /// await store.receive(.response(.success(42)) {
    ///   $0.count = 42
    /// }
    /// ```
    ///
    /// Due to the variability of concurrency in Swift, sometimes a small amount of time needs to
    /// pass before effects execute and send actions, and that is why this method suspends. The
    /// default time waited is very small, and typically it is enough so you should be controlling
    /// your dependencies so that they do not wait for real world time to pass (see
    /// <doc:DependencyManagement> for more information on how to do that).
    ///
    /// To change the amount of time this method waits for an action, pass an explicit `timeout`
    /// argument, or set the ``timeout`` on the ``TestStore``.
    ///
    /// - Parameters:
    ///   - expectedAction: An action expected from an effect.
    ///   - duration: The amount of time to wait for the expected action.
    ///   - updateStateToExpectedResult: A closure that asserts state changed by sending the action
    ///     to the store. The mutable state sent to this closure must be modified to match the state
    ///     of the store after processing the given action. Do not provide a closure if no change
    ///     is expected.
    @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
    @MainActor
    public func receive(
      _ expectedAction: Action,
      timeout duration: Duration,
      assert updateStateToExpectedResult: ((_ state: inout State) throws -> Void)? = nil,
      file: StaticString = #file,
      line: UInt = #line
    ) async {
      await self.receive(
        expectedAction,
        timeout: duration.nanoseconds,
        assert: updateStateToExpectedResult,
        file: file,
        line: line
      )
    }
  #endif

  /// Asserts an action was received from an effect and asserts how the state changes.
  ///
  /// When an effect is executed in your feature and sends an action back into the system, you can
  /// use this method to assert that fact, and further assert how state changes after the effect
  /// action is received:
  ///
  /// ```swift
  /// await store.send(.buttonTapped)
  /// await store.receive(.response(.success(42)) {
  ///   $0.count = 42
  /// }
  /// ```
  ///
  /// Due to the variability of concurrency in Swift, sometimes a small amount of time needs to pass
  /// before effects execute and send actions, and that is why this method suspends. The default
  /// time waited is very small, and typically it is enough so you should be controlling your
  /// dependencies so that they do not wait for real world time to pass (see
  /// <doc:DependencyManagement> for more information on how to do that).
  ///
  /// To change the amount of time this method waits for an action, pass an explicit `timeout`
  /// argument, or set the ``timeout`` on the ``TestStore``.
  ///
  /// - Parameters:
  ///   - expectedAction: An action expected from an effect.
  ///   - nanoseconds: The amount of time to wait for the expected action.
  ///   - updateStateToExpectedResult: A closure that asserts state changed by sending the action to
  ///     the store. The mutable state sent to this closure must be modified to match the state of
  ///     the store after processing the given action. Do not provide a closure if no change is
  ///     expected.
  @MainActor
  @_disfavoredOverload
  public func receive(
    _ expectedAction: Action,
    timeout nanoseconds: UInt64? = nil,
    assert updateStateToExpectedResult: ((_ state: inout State) throws -> Void)? = nil,
    file: StaticString = #file,
    line: UInt = #line
  ) async {
    await XCTFailContext.$current.withValue(XCTFailContext(file: file, line: line)) {
      guard !self.reducer.inFlightEffects.isEmpty
      else {
        _ = {
          self._receive(
            expectedAction, assert: updateStateToExpectedResult, file: file, line: line)
        }()
        return
      }
      await self.receiveAction(
        matching: { expectedAction == $0 },
        timeout: nanoseconds,
        file: file,
        line: line
      )
      _ = {
        self._receive(expectedAction, assert: updateStateToExpectedResult, file: file, line: line)
      }()
      await Task.megaYield()
    }
  }
}

extension TestStore where State: Equatable {
  private func _receive(
    _ isMatching: (Action) -> Bool,
    assert updateStateToExpectedResult: ((inout State) throws -> Void)? = nil,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    self.receiveAction(
      matching: isMatching,
      failureMessage: "Expected to receive an action matching predicate, but didn't get one.",
      unexpectedActionDescription: { receivedAction in
        var action = ""
        customDump(receivedAction, to: &action, indent: 2)
        return action
      },
      updateStateToExpectedResult,
      file: file,
      line: line
    )
  }

  private func _receive<Value>(
    _ actionCase: AnyCasePath<Action, Value>,
    assert updateStateToExpectedResult: ((inout State) throws -> Void)? = nil,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    self.receiveAction(
      matching: { actionCase.extract(from: $0) != nil },
      failureMessage: "Expected to receive an action matching case path, but didn't get one.",
      unexpectedActionDescription: { receivedAction in
        var action = ""
        customDump(receivedAction, to: &action, indent: 2)
        return action
      },
      updateStateToExpectedResult,
      file: file,
      line: line
    )
  }

  private func _receive<Value: Equatable>(
    _ actionCase: AnyCasePath<Action, Value>,
    _ value: Value,
    assert updateStateToExpectedResult: ((inout State) throws -> Void)? = nil,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    self.receiveAction(
      matching: { actionCase.extract(from: $0) == value },
      failureMessage: "Expected to receive an action matching case path, but didn't get one.",
      unexpectedActionDescription: { receivedAction in
        var action = ""
        if actionCase.extract(from: receivedAction) != nil,
          let difference = diff(actionCase.embed(value), receivedAction, format: .proportional)
        {
          action.append(
            """
            \(difference.indent(by: 2))

            (Expected: −, Actual: +)
            """
          )
        } else {
          customDump(receivedAction, to: &action, indent: 2)
        }
        return action
      },
      updateStateToExpectedResult,
      file: file,
      line: line
    )
  }

  // NB: Only needed until Xcode ships a macOS SDK that uses the 5.7 standard library.
  // See: https://forums.swift.org/t/xcode-14-rc-cannot-specialize-protocol-type/60171/15
  #if (canImport(RegexBuilder) || !os(macOS) && !targetEnvironment(macCatalyst))
    /// Asserts an action was received from an effect that matches a predicate, and asserts how the
    /// state changes.
    ///
    /// This method is similar to ``receive(_:timeout:assert:file:line:)-6325h``, except it allows
    /// you to assert that an action was received that matches a predicate instead of a case key
    /// path:
    ///
    /// ```swift
    /// await store.send(.buttonTapped)
    /// await store.receive {
    ///   guard case .response(.success) = $0 else { return false }
    ///   return true
    /// } assert: {
    ///   store.count = 42
    /// }
    /// ```
    ///
    /// When the store's ``exhaustivity`` is set to anything other than ``Exhaustivity/off``, a grey
    /// information box will show next to the `store.receive` line in Xcode letting you know what
    /// data was in the effect that you chose not to assert on.
    ///
    /// If you only want to check that a particular action case was received, then you might find
    /// the ``receive(_:timeout:assert:file:line:)-6325h`` overload of this method more useful.
    ///
    /// - Parameters:
    ///   - isMatching: A closure that attempts to match an action. If it returns `false`, a test
    ///     failure is reported.
    ///   - duration: The amount of time to wait for the expected action.
    ///   - updateStateToExpectedResult: A closure that asserts state changed by sending the action
    ///     to the store. The mutable state sent to this closure must be modified to match the state
    ///     of the store after processing the given action. Do not provide a closure if no change is
    ///     expected.
    @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
    @MainActor
    @_disfavoredOverload
    public func receive(
      _ isMatching: (_ action: Action) -> Bool,
      timeout duration: Duration,
      assert updateStateToExpectedResult: ((_ state: inout State) throws -> Void)? = nil,
      file: StaticString = #file,
      line: UInt = #line
    ) async {
      await self.receive(
        isMatching,
        timeout: duration.nanoseconds,
        assert: updateStateToExpectedResult,
        file: file,
        line: line
      )
    }
  #endif

  /// Asserts an action was received from an effect that matches a predicate, and asserts how the
  /// state changes.
  ///
  /// This method is similar to ``receive(_:timeout:assert:file:line:)-6325h``, except it allows
  /// you to assert that an action was received that matches a predicate instead of a case key
  /// path:
  ///
  /// ```swift
  /// await store.send(.buttonTapped)
  /// await store.receive {
  ///   guard case .response(.success) = $0 else { return false }
  ///   return true
  /// } assert: {
  ///   store.count = 42
  /// }
  /// ```
  ///
  /// When the store's ``exhaustivity`` is set to anything other than ``Exhaustivity/off``, a grey
  /// information box will show next to the `store.receive` line in Xcode letting you know what data
  /// was in the effect that you chose not to assert on.
  ///
  /// If you only want to check that a particular action case was received, then you might find the
  /// ``receive(_:timeout:assert:file:line:)-6325h`` overload of this method more useful.
  ///
  /// - Parameters:
  ///   - isMatching: A closure that attempts to match an action. If it returns `false`, a test
  ///     failure is reported.
  ///   - nanoseconds: The amount of time to wait for the expected action.
  ///   - updateStateToExpectedResult: A closure that asserts state changed by sending the action to
  ///     the store. The mutable state sent to this closure must be modified to match the state of
  ///     the store after processing the given action. Do not provide a closure if no change is
  ///     expected.
  @MainActor
  @_disfavoredOverload
  public func receive(
    _ isMatching: (_ action: Action) -> Bool,
    timeout nanoseconds: UInt64? = nil,
    assert updateStateToExpectedResult: ((_ state: inout State) throws -> Void)? = nil,
    file: StaticString = #file,
    line: UInt = #line
  ) async {
    await XCTFailContext.$current.withValue(XCTFailContext(file: file, line: line)) {
      guard !self.reducer.inFlightEffects.isEmpty
      else {
        _ = {
          self._receive(isMatching, assert: updateStateToExpectedResult, file: file, line: line)
        }()
        return
      }
      await self.receiveAction(matching: isMatching, timeout: nanoseconds, file: file, line: line)
      _ = {
        self._receive(isMatching, assert: updateStateToExpectedResult, file: file, line: line)
      }()
      await Task.megaYield()
    }
  }

  /// Asserts an action was received matching a case path and asserts how the state changes.
  ///
  /// This method is similar to ``receive(_:timeout:assert:file:line:)-7md3m``, except it allows
  /// you to assert that an action was received that matches a case key path instead of a predicate.
  ///
  /// It can be useful to assert that a particular action was received without asserting on the data
  /// inside the action. For example:
  ///
  /// ```swift
  /// await store.receive(/Search.Action.searchResponse) {
  ///   $0.results = [
  ///     "CasePaths",
  ///     "ComposableArchitecture",
  ///     "IdentifiedCollections",
  ///     "XCTestDynamicOverlay",
  ///   ]
  /// }
  /// ```
  ///
  /// When the store's ``exhaustivity`` is set to anything other than ``Exhaustivity/off``, a grey
  /// information box will show next to the `store.receive` line in Xcode letting you know what data
  /// was in the effect that you chose not to assert on.
  ///
  /// - Parameters:
  ///   - actionCase: A case path identifying the case of an action to enum to receive
  ///   - nanoseconds: The amount of time to wait for the expected action.
  ///   - updateStateToExpectedResult: A closure that asserts state changed by sending the action to
  ///     the store. The mutable state sent to this closure must be modified to match the state of
  ///     the store after processing the given action. Do not provide a closure if no change is
  ///     expected.
  @MainActor
  @_disfavoredOverload
  public func receive<Value>(
    _ actionCase: CaseKeyPath<Action, Value>,
    timeout nanoseconds: UInt64? = nil,
    assert updateStateToExpectedResult: ((_ state: inout State) throws -> Void)? = nil,
    file: StaticString = #file,
    line: UInt = #line
  ) async {
    await self.receive(
      AnyCasePath(actionCase),
      timeout: nanoseconds,
      assert: updateStateToExpectedResult,
      file: file,
      line: line
    )
  }

  /// Asserts an action was received matching a case path with a specific payload, and asserts
  /// how the state changes.
  ///
  /// This method is similar to ``receive(_:timeout:assert:file:line:)-6325h``, except it allows
  /// you to assert on the value inside the action too.
  ///
  /// It can be useful when asserting on delegate actions sent by a child feature:
  ///
  /// ```swift
  /// await store.receive(\.delegate.success, "Hello!")
  /// ```
  ///
  /// When the store's ``exhaustivity`` is set to anything other than ``Exhaustivity/off``, a grey
  /// information box will show next to the `store.receive` line in Xcode letting you know what
  /// data was in the effect that you chose not to assert on.
  ///
  /// - Parameters:
  ///   - actionCase: A case path identifying the case of an action to enum to receive
  ///   - value: The value to match in the action.
  ///   - duration: The amount of time to wait for the expected action.
  ///   - updateStateToExpectedResult: A closure that asserts state changed by sending the action
  ///     to the store. The mutable state sent to this closure must be modified to match the state
  ///     of the store after processing the given action. Do not provide a closure if no change is
  ///     expected.
  @MainActor
  @_disfavoredOverload
  public func receive<Value: Equatable>(
    _ actionCase: CaseKeyPath<Action, Value>,
    _ value: Value,
    timeout nanoseconds: UInt64? = nil,
    assert updateStateToExpectedResult: ((_ state: inout State) throws -> Void)? = nil,
    file: StaticString = #file,
    line: UInt = #line
  ) async
  where Action: CasePathable {
    let actionCase = AnyCasePath(actionCase)
    await XCTFailContext.$current.withValue(XCTFailContext(file: file, line: line)) {
      guard !self.reducer.inFlightEffects.isEmpty
      else {
        _ = {
          self._receive(
            actionCase, value, assert: updateStateToExpectedResult, file: file, line: line
          )
        }()
        return
      }
      await self.receiveAction(
        matching: { actionCase.extract(from: $0) != nil },
        timeout: nanoseconds,
        file: file,
        line: line
      )
      _ = {
        self._receive(
          actionCase, value, assert: updateStateToExpectedResult, file: file, line: line
        )
      }()
      await Task.megaYield()
    }
  }

  @available(
    iOS,
    deprecated: 9999,
    message:
      "Use the version of this operator with case key paths, instead. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
  )
  @available(
    macOS,
    deprecated: 9999,
    message:
      "Use the version of this operator with case key paths, instead. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
  )
  @available(
    tvOS,
    deprecated: 9999,
    message:
      "Use the version of this operator with case key paths, instead. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
  )
  @available(
    watchOS,
    deprecated: 9999,
    message:
      "Use the version of this operator with case key paths, instead. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
  )
  @MainActor
  @_disfavoredOverload
  public func receive<Value>(
    _ actionCase: AnyCasePath<Action, Value>,
    timeout nanoseconds: UInt64? = nil,
    assert updateStateToExpectedResult: ((_ state: inout State) throws -> Void)? = nil,
    file: StaticString = #file,
    line: UInt = #line
  ) async {
    await XCTFailContext.$current.withValue(XCTFailContext(file: file, line: line)) {
      guard !self.reducer.inFlightEffects.isEmpty
      else {
        _ = {
          self._receive(actionCase, assert: updateStateToExpectedResult, file: file, line: line)
        }()
        return
      }
      await self.receiveAction(
        matching: { actionCase.extract(from: $0) != nil },
        timeout: nanoseconds,
        file: file,
        line: line
      )
      _ = {
        self._receive(actionCase, assert: updateStateToExpectedResult, file: file, line: line)
      }()
      await Task.megaYield()
    }
  }

  #if (canImport(RegexBuilder) || !os(macOS) && !targetEnvironment(macCatalyst))
    /// Asserts an action was received matching a case path and asserts how the state changes.
    ///
    /// This method is similar to ``receive(_:timeout:assert:file:line:)-7md3m``, except it allows
    /// you to assert that an action was received that matches a case key path instead of a
    /// predicate.
    ///
    /// It can be useful to assert that a particular action was received without asserting
    /// on the data inside the action. For example:
    ///
    /// ```swift
    /// await store.receive(\.searchResponse) {
    ///   $0.results = [
    ///     "CasePaths",
    ///     "ComposableArchitecture",
    ///     "IdentifiedCollections",
    ///     "XCTestDynamicOverlay",
    ///   ]
    /// }
    /// ```
    ///
    /// When the store's ``exhaustivity`` is set to anything other than ``Exhaustivity/off``, a grey
    /// information box will show next to the `store.receive` line in Xcode letting you know what
    /// data was in the effect that you chose not to assert on.
    ///
    /// - Parameters:
    ///   - actionCase: A case path identifying the case of an action to enum to receive
    ///   - duration: The amount of time to wait for the expected action.
    ///   - updateStateToExpectedResult: A closure that asserts state changed by sending the action
    ///     to the store. The mutable state sent to this closure must be modified to match the state
    ///     of the store after processing the given action. Do not provide a closure if no change is
    ///     expected.
    @MainActor
    @_disfavoredOverload
    @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
    public func receive<Value>(
      _ actionCase: CaseKeyPath<Action, Value>,
      timeout duration: Duration,
      assert updateStateToExpectedResult: ((_ state: inout State) throws -> Void)? = nil,
      file: StaticString = #file,
      line: UInt = #line
    ) async {
      await self.receive(
        AnyCasePath(actionCase),
        timeout: duration,
        assert: updateStateToExpectedResult,
        file: file,
        line: line
      )
    }

    /// Asserts an action was received matching a case path with a specific payload, and asserts
    /// how the state changes.
    ///
    /// This method is similar to ``receive(_:timeout:assert:file:line:)-6325h``, except it allows
    /// you to assert on the value inside the action too.
    ///
    /// It can be useful when asserting on delegate actions sent by a child feature:
    ///
    /// ```swift
    /// await store.receive(\.delegate.success, "Hello!")
    /// ```
    ///
    /// When the store's ``exhaustivity`` is set to anything other than ``Exhaustivity/off``, a grey
    /// information box will show next to the `store.receive` line in Xcode letting you know what
    /// data was in the effect that you chose not to assert on.
    ///
    /// - Parameters:
    ///   - actionCase: A case path identifying the case of an action to enum to receive
    ///   - value: The value to match in the action.
    ///   - duration: The amount of time to wait for the expected action.
    ///   - updateStateToExpectedResult: A closure that asserts state changed by sending the action
    ///     to the store. The mutable state sent to this closure must be modified to match the state
    ///     of the store after processing the given action. Do not provide a closure if no change is
    ///     expected.
    @MainActor
    @_disfavoredOverload
    @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
    public func receive<Value: Equatable>(
      _ actionCase: CaseKeyPath<Action, Value>,
      _ value: Value,
      timeout duration: Duration,
      assert updateStateToExpectedResult: ((_ state: inout State) throws -> Void)? = nil,
      file: StaticString = #file,
      line: UInt = #line
    ) async
    where Action: CasePathable {
      await self.receive(
        AnyCasePath(
          embed: { actionCase($0) },
          extract: { action in
            action[case: actionCase].flatMap { $0 == value ? $0 : nil }
          }
        ),
        timeout: duration,
        assert: updateStateToExpectedResult,
        file: file,
        line: line
      )
    }

    @MainActor
    @_disfavoredOverload
    @available(
      iOS,
      introduced: 16,
      deprecated: 9999,
      message:
        "Use the version of this operator with case key paths, instead. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
    )
    @available(
      macOS,
      introduced: 13,
      deprecated: 9999,
      message:
        "Use the version of this operator with case key paths, instead. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
    )
    @available(
      tvOS,
      introduced: 16,
      deprecated: 9999,
      message:
        "Use the version of this operator with case key paths, instead. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
    )
    @available(
      watchOS,
      introduced: 9,
      deprecated: 9999,
      message:
        "Use the version of this operator with case key paths, instead. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
    )
    public func receive<Value>(
      _ actionCase: AnyCasePath<Action, Value>,
      timeout duration: Duration,
      assert updateStateToExpectedResult: ((_ state: inout State) throws -> Void)? = nil,
      file: StaticString = #file,
      line: UInt = #line
    ) async {
      await XCTFailContext.$current.withValue(XCTFailContext(file: file, line: line)) {
        guard !self.reducer.inFlightEffects.isEmpty
        else {
          _ = {
            self._receive(
              actionCase, assert: updateStateToExpectedResult, file: file, line: line
            )
          }()
          return
        }
        await self.receiveAction(
          matching: { actionCase.extract(from: $0) != nil },
          timeout: duration.nanoseconds,
          file: file,
          line: line
        )
        _ = {
          self._receive(actionCase, assert: updateStateToExpectedResult, file: file, line: line)
        }()
        await Task.megaYield()
      }
    }
  #endif

  private func receiveAction(
    matching predicate: (Action) -> Bool,
    failureMessage: @autoclosure () -> String,
    unexpectedActionDescription: (Action) -> String,
    _ updateStateToExpectedResult: ((inout State) throws -> Void)?,
    file: StaticString,
    line: UInt
  ) {
    let updateStateToExpectedResult = updateStateToExpectedResult.map { original in
      { (state: inout State) in
        try XCTModifyLocals.$isExhaustive.withValue(self.exhaustivity == .on) {
          try original(&state)
        }
      }
    }

    guard !self.reducer.receivedActions.isEmpty else {
      XCTFail(
        failureMessage(),
        file: file,
        line: line
      )
      return
    }

    if self.exhaustivity != .on {
      guard self.reducer.receivedActions.contains(where: { predicate($0.action) }) else {
        XCTFail(
          failureMessage(),
          file: file,
          line: line
        )
        return
      }

      var actions: [Action] = []
      while let receivedAction = self.reducer.receivedActions.first,
        !predicate(receivedAction.action)
      {
        self.reducer.receivedActions.removeFirst()
        actions.append(receivedAction.action)
        self.reducer.state = receivedAction.state
      }

      if !actions.isEmpty {
        var actionsDump = ""
        customDump(actions, to: &actionsDump)
        XCTFailHelper(
          """
          \(actions.count) received action\
          \(actions.count == 1 ? " was" : "s were") skipped:

          \(actionsDump)
          """,
          file: file,
          line: line
        )
      }
    }

    let (receivedAction, state) = self.reducer.receivedActions.removeFirst()
    if !predicate(receivedAction) {
      let receivedActionLater = self.reducer.receivedActions
        .contains(where: { action, _ in predicate(receivedAction) })
      XCTFailHelper(
        """
        Received unexpected action\(receivedActionLater ? " before this one" : ""): …

        \(unexpectedActionDescription(receivedAction))
        """,
        file: file,
        line: line
      )
    } else {
      let expectedState = self.state
      do {
        try self.expectedStateShouldMatch(
          expected: expectedState,
          actual: state,
          updateStateToExpectedResult: updateStateToExpectedResult,
          file: file,
          line: line
        )
      } catch {
        XCTFail("Threw error: \(error)", file: file, line: line)
      }
    }
    self.reducer.state = state
  }

  @MainActor
  private func receiveAction(
    matching predicate: (Action) -> Bool,
    timeout nanoseconds: UInt64?,
    file: StaticString,
    line: UInt
  ) async {
    let nanoseconds = nanoseconds ?? self.timeout

    await Task.megaYield()
    let start = DispatchTime.now().uptimeNanoseconds
    while !Task.isCancelled {
      await Task.detached(priority: .background) { await Task.yield() }.value

      switch self.exhaustivity {
      case .on:
        guard self.reducer.receivedActions.isEmpty
        else { return }
      case .off:
        guard !self.reducer.receivedActions.contains(where: { predicate($0.action) })
        else { return }
      }

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
          Expected to receive \(self.exhaustivity == .on ? "an action" : "a matching action"), but \
          received none\
          \(nanoseconds > 0 ? " after \(Double(nanoseconds)/Double(NSEC_PER_SEC)) seconds" : "").

          \(suggestion)
          """,
          file: file,
          line: line
        )
        return
      }
    }
  }
}

extension TestStore where State: Equatable {
  /// Sends an action to the store and asserts when state changes.
  ///
  /// This method is similar to ``send(_:assert:file:line:)-2co21``, except it allows you to specify
  /// a case key path to an action, which can be useful when testing the integration of features and
  /// sending deeply nested actions. For example:
  ///
  /// ```swift
  /// await store.send(.destination(.presented(.child(.tap))))
  /// ```
  ///
  /// Can be simplified to:
  ///
  /// ```swift
  /// await store.send(\.destination.child.tap)
  /// ```
  ///
  /// - Parameters:
  ///   - action: A case key path to an action.
  ///   - updateStateToExpectedResult: A closure that asserts state changed by sending the action to
  ///     the store. The mutable state sent to this closure must be modified to match the state of
  ///     the store after processing the given action. Do not provide a closure if no change is
  ///     expected.
  /// - Returns: A ``TestStoreTask`` that represents the lifecycle of the effect executed when
  ///   sending the action.
  @MainActor
  @discardableResult
  @_disfavoredOverload
  public func send(
    _ action: CaseKeyPath<Action, Void>,
    assert updateStateToExpectedResult: ((_ state: inout State) throws -> Void)? = nil,
    file: StaticString = #file,
    line: UInt = #line
  ) async -> TestStoreTask {
    await self.send(action(), assert: updateStateToExpectedResult, file: file, line: line)
  }

  /// Sends an action to the store and asserts when state changes.
  ///
  /// This method is similar to ``send(_:assert:file:line:)-1oopl``, except it allows
  /// you to specify a value for the associated value of the action.
  ///
  /// It can be useful when sending nested action.  For example::
  ///
  /// ```swift
  /// await store.send(.destination(.presented(.child(.emailChanged("blob@pointfree.co")))))
  /// ```
  ///
  /// Can be simplified to:
  ///
  /// ```swift
  /// await store.send(\.destination.child.emailChanged, "blob@pointfree.co")
  /// ```
  ///
  /// - Parameters:
  ///   - action: A case key path to an action.
  ///   - value: A value to embed in `action`.
  ///   - updateStateToExpectedResult: A closure that asserts state changed by sending the action to
  ///     the store. The mutable state sent to this closure must be modified to match the state of
  ///     the store after processing the given action. Do not provide a closure if no change is
  ///     expected.
  /// - Returns: A ``TestStoreTask`` that represents the lifecycle of the effect executed when
  ///   sending the action.
  @MainActor
  @discardableResult
  @_disfavoredOverload
  public func send<Value>(
    _ action: CaseKeyPath<Action, Value>,
    _ value: Value,
    assert updateStateToExpectedResult: ((_ state: inout State) throws -> Void)? = nil,
    file: StaticString = #file,
    line: UInt = #line
  ) async -> TestStoreTask {
    await self.send(action(value), assert: updateStateToExpectedResult, file: file, line: line)
  }
}

extension TestStore {
  /// Clears the queue of received actions from effects.
  ///
  /// Can be handy if you are writing an exhaustive test for a particular part of your feature, but
  /// you don't want to explicitly deal with all of the received actions:
  ///
  /// ```swift
  /// let store = TestStore(/* ... */)
  ///
  /// await store.send(.buttonTapped) {
  ///   // Assert on how state changed
  /// }
  /// await store.receive(\.response) {
  ///   // Assert on how state changed
  /// }
  ///
  /// // Make it explicit you do not want to assert on any other received actions.
  /// await store.skipReceivedActions()
  /// ```
  ///
  /// - Parameter strict: When `true` and there are no in-flight actions to cancel, a test failure
  ///   will be reported.
  @MainActor
  public func skipReceivedActions(
    strict: Bool = true,
    file: StaticString = #file,
    line: UInt = #line
  ) async {
    await Task.megaYield()
    _ = { self._skipReceivedActions(strict: strict, file: file, line: line) }()
  }

  private func _skipReceivedActions(
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
      \(self.reducer.receivedActions.count == 1 ? " was" : "s were") skipped:

      \(actions)
      """,
      overrideExhaustivity: self.exhaustivity == .on
        ? .off(showSkippedAssertions: true)
        : self.exhaustivity,
      file: file,
      line: line
    )
    self.reducer.state = self.reducer.receivedActions.last!.state
    self.reducer.receivedActions = []
  }

  /// Cancels any currently in-flight effects.
  ///
  /// Can be handy if you are writing an exhaustive test for a particular part of your feature, but
  /// you don't want to explicitly deal with all effects:
  ///
  /// ```swift
  /// let store = TestStore(/* ... */)
  ///
  /// await store.send(.buttonTapped) {
  ///   // Assert on how state changed
  /// }
  /// await store.receive(\.response) {
  ///   // Assert on how state changed
  /// }
  ///
  /// // Make it explicit you do not want to assert on how any other effects behave.
  /// await store.skipInFlightEffects()
  /// ```
  ///
  /// - Parameter strict: When `true` and there are no in-flight actions to cancel, a test failure
  ///   will be reported.
  @MainActor
  public func skipInFlightEffects(
    strict: Bool = true,
    file: StaticString = #file,
    line: UInt = #line
  ) async {
    await Task.megaYield()
    _ = { self._skipInFlightEffects(strict: strict, file: file, line: line) }()
  }

  private func _skipInFlightEffects(
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
      overrideExhaustivity: self.exhaustivity == .on
        ? .off(showSkippedAssertions: true)
        : self.exhaustivity,
      file: file,
      line: line
    )
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
    case .on:
      XCTFail(message, file: file, line: line)
    case .off(showSkippedAssertions: true):
      XCTExpectFailure {
        XCTFail(
          """
          Skipped assertions: …

          \(message)
          """,
          file: file,
          line: line
        )
      }
    case .off(showSkippedAssertions: false):
      break
    }
  }
}

extension TestStore {
  /// Returns a binding view store for this store.
  ///
  /// Useful for testing view state of a store.
  ///
  /// ```swift
  /// let store = TestStore(LoginFeature.State()) {
  ///   Login.Feature()
  /// }
  /// await store.send(.view(.set(\.$email, "blob@pointfree.co"))) {
  ///   $0.email = "blob@pointfree.co"
  /// }
  /// XCTAssertTrue(
  ///   LoginView.ViewState(store.bindings(action: \.view))
  ///     .isLoginButtonDisabled
  /// )
  ///
  /// await store.send(.view(.set(\.$password, "whats-the-point?"))) {
  ///   $0.password = "blob@pointfree.co"
  ///   $0.isFormValid = true
  /// }
  /// XCTAssertFalse(
  ///   LoginView.ViewState(store.bindings(action: \.view))
  ///     .isLoginButtonDisabled
  /// )
  /// ```
  ///
  /// - Parameter toViewAction: A case path from action to a bindable view action.
  /// - Returns: A binding view store.
  public func bindings<ViewAction: BindableAction>(
    action toViewAction: CaseKeyPath<Action, ViewAction>
  ) -> BindingViewStore<State> where State == ViewAction.State, Action: CasePathable {
    BindingViewStore(
      store: Store(initialState: self.state) {
        BindingReducer(action: toViewAction)
      }
      .scope(state: \.self, action: toViewAction)
    )
  }

  @available(
    iOS,
    deprecated: 9999,
    message:
      "Use the version of this operator with case key paths, instead. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
  )
  @available(
    macOS,
    deprecated: 9999,
    message:
      "Use the version of this operator with case key paths, instead. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
  )
  @available(
    tvOS,
    deprecated: 9999,
    message:
      "Use the version of this operator with case key paths, instead. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
  )
  @available(
    watchOS,
    deprecated: 9999,
    message:
      "Use the version of this operator with case key paths, instead. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
  )
  public func bindings<ViewAction: BindableAction>(
    action toViewAction: AnyCasePath<Action, ViewAction>
  ) -> BindingViewStore<State> where State == ViewAction.State {
    BindingViewStore(
      store: Store(initialState: self.state) {
        BindingReducer(action: toViewAction.extract(from:))
      }
      .scope(
        id: nil,
        state: ToState(\.self),
        action: toViewAction.embed,
        isInvalid: nil
      )
    )
  }
}

extension TestStore where Action: BindableAction, State == Action.State {
  /// Returns a binding view store for this store.
  ///
  /// Useful for testing view state of a store.
  ///
  /// ```swift
  /// let store = TestStore(LoginFeature.State()) {
  ///   Login.Feature()
  /// }
  /// await store.send(.set(\.$email, "blob@pointfree.co")) {
  ///   $0.email = "blob@pointfree.co"
  /// }
  /// XCTAssertTrue(LoginView.ViewState(store.bindings).isLoginButtonDisabled)
  ///
  /// await store.send(.set(\.$password, "whats-the-point?")) {
  ///   $0.password = "blob@pointfree.co"
  ///   $0.isFormValid = true
  /// }
  /// XCTAssertFalse(LoginView.ViewState(store.bindings).isLoginButtonDisabled)
  /// ```
  ///
  /// - Returns: A binding view store.
  public var bindings: BindingViewStore<State> {
    self.bindings(action: AnyCasePath())
  }
}

/// The type returned from ``TestStore/send(_:assert:file:line:)-2co21`` that represents the
/// lifecycle of the effect started from sending an action.
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
/// await store.receive(\.timerTick) { $0.elapsed = 1 }
///
/// // Wait for cleanup effects to finish before completing the test
/// await store.send(.stopTimerButtonTapped).finish()
/// ```
///
/// See ``TestStore/finish(timeout:file:line:)-53gi5`` for the ability to await all in-flight
/// effects in the test store.
///
/// See ``StoreTask`` for the analog provided to ``Store``.
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
  /// but cancellation of that effect is handled by the parent when the feature disappears. Such a
  /// feature is difficult to exhaustively test in isolation because there is no action in its
  /// domain that cancels the effect:
  ///
  /// ```swift
  /// let store = TestStore(/* ... */)
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
  #if (canImport(RegexBuilder) || !os(macOS) && !targetEnvironment(macCatalyst))
    /// Asserts the underlying task finished.
    ///
    /// - Parameter duration: The amount of time to wait before asserting.
    @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
    public func finish(
      timeout duration: Duration,
      file: StaticString = #file,
      line: UInt = #line
    ) async {
      await self.finish(timeout: duration.nanoseconds, file: file, line: line)
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

class TestReducer<State, Action>: Reducer {
  let base: Reduce<State, Action>
  var dependencies: DependencyValues
  let effectDidSubscribe = AsyncStream.makeStream(of: Void.self)
  var inFlightEffects: Set<LongLivingEffect> = []
  var receivedActions: [(action: Action, state: State)] = []
  var state: State

  init(
    _ base: Reduce<State, Action>,
    initialState: State
  ) {
    @Dependency(\.self) var dependencies
    self.base = base
    self.dependencies = dependencies
    self.state = initialState
  }

  func reduce(into state: inout State, action: TestAction) -> Effect<TestAction> {
    let reducer = self.base
      .dependency(\.self, self.dependencies)

    let effects: Effect<Action>
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
      return .publisher { [effectDidSubscribe, weak self] in
        _EffectPublisher(effects)
          .handleEvents(
            receiveSubscription: { _ in
              self?.inFlightEffects.insert(effect)
              Task {
                await Task.megaYield()
                effectDidSubscribe.continuation.yield()
              }
            },
            receiveCompletion: { [weak self] _ in
              self?.inFlightEffects.remove(effect)
            },
            receiveCancel: { [weak self] in
              self?.inFlightEffects.remove(effect)
            }
          )
          .map { .init(origin: .receive($0), file: action.file, line: action.line) }
      }
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

    fileprivate var action: Action {
      self.origin.action
    }

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

// NB: Only needed until Xcode ships a macOS SDK that uses the 5.7 standard library.
// See: https://forums.swift.org/t/xcode-14-rc-cannot-specialize-protocol-type/60171/15
#if (canImport(RegexBuilder) || !os(macOS) && !targetEnvironment(macCatalyst))
  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  extension Duration {
    fileprivate var nanoseconds: UInt64 {
      UInt64(self.components.seconds) * NSEC_PER_SEC
        + UInt64(self.components.attoseconds) / 1_000_000_000
    }
  }
#endif

/// The exhaustivity of assertions made by the test store.
public enum Exhaustivity: Equatable, Sendable {
  /// Exhaustive assertions.
  ///
  /// This setting requires you to exhaustively assert on all state changes and all actions received
  /// from effects. Additionally, all in-flight effects _must_ be received before the test store is
  /// deallocated.
  ///
  /// To manually skip actions or effects, use
  /// ``TestStore/skipReceivedActions(strict:file:line:)-a4ri`` or
  /// ``TestStore/skipInFlightEffects(strict:file:line:)-5hbsk``.
  ///
  /// To partially match an action received from an effect, use
  /// ``TestStore/receive(_:timeout:assert:file:line:)-6325h`` or
  /// ``TestStore/receive(_:timeout:assert:file:line:)-7md3m``.

  case on

  /// Non-exhaustive assertions.
  ///
  /// This settings allows you to assert on any subset of state changes and actions received from
  /// effects.
  ///
  /// When configured to `showSkippedAssertions`, any state not asserted on or received actions
  /// skipped will be reported in a grey informational box next to the assertion. This is handy for
  /// when you want non-exhaustivity but you still want to know what all you are missing from your
  /// assertions.
  ///
  /// - Parameter showSkippedAssertions: When `true`, skipped assertions will be reported as
  ///   expected failures.
  case off(showSkippedAssertions: Bool)

  /// Non-exhaustive assertions.
  public static let off = Self.off(showSkippedAssertions: false)
}

extension TestStore {
  @MainActor
  @available(
    *,
    unavailable,
    message:
      "Provide a key path to the case you expect to receive (like 'store.receive(\\.tap)'), or conform 'Action' to 'Equatable' to assert against it directly."
  )
  public func receive(
    _ expectedAction: Action,
    assert updateStateToExpectedResult: ((_ state: inout State) throws -> Void)? = nil,
    file: StaticString = #file,
    line: UInt = #line
  ) async {
  }
}
