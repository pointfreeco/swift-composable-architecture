#if DEBUG
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
  /// struct CounterState {
  ///   var count = 0
  /// }
  /// enum CounterAction: Equatable {
  ///   case decrementButtonTapped
  ///   case incrementButtonTapped
  /// }
  ///
  /// let counterReducer = Reducer<CounterState, CounterAction, Void> { state, action, _ in
  ///   switch action {
  ///   case .decrementButtonTapped:
  ///     state.count -= 1
  ///     return .none
  ///
  ///   case .incrementButtonTapped:
  ///     state.count += 1
  ///     return .none
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
  ///       initialState: CounterState(count: 0),     // Given a counter state of 0
  ///       reducer: counterReducer,
  ///       environment: ()
  ///     )
  ///     await store.send(.incrementButtonTapped) {  // When the increment button is tapped
  ///       $0.count = 1                              // Then the count should be 1
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// Note that in the trailing closure of `.send(.incrementButtonTapped)` we are given a single
  /// mutable value of the state before the action was sent, and it is our job to mutate the value
  /// to match the state after the action was sent. In this case the `count` field changes to `1`.
  ///
  /// For a more complex example, consider the following bare-bones search feature that uses the
  /// ``Effect/debounce(id:for:scheduler:options:)-76yye`` operator to wait for the user to stop
  /// typing before making a network request:
  ///
  /// ```swift
  /// struct SearchState: Equatable {
  ///   var query = ""
  ///   var results: [String] = []
  /// }
  ///
  /// enum SearchAction: Equatable {
  ///   case queryChanged(String)
  ///   case response([String])
  /// }
  ///
  /// struct SearchEnvironment {
  ///   var mainQueue: AnySchedulerOf<DispatchQueue>
  ///   var request: (String) async throws -> [String]
  /// }
  ///
  /// let searchReducer = Reducer<SearchState, SearchAction, SearchEnvironment> {
  ///   state, action, environment in
  ///     switch action {
  ///     case let .queryChanged(query):
  ///       enum SearchID {}
  ///
  ///       state.query = query
  ///       return .run { send in
  ///         guard let results = try? await environment.request(query) else { return }
  ///         send(.response(results))
  ///       }
  ///       .debounce(id: SearchID.self, for: 0.5, scheduler: environment.mainQueue)
  ///
  ///     case let .response(results):
  ///       state.results = results
  ///       return .none
  ///     }
  /// }
  /// ```
  ///
  /// It can be fully tested by controlling the environment's scheduler and effect:
  ///
  /// ```swift
  /// // Create a test dispatch scheduler to control the timing of effects
  /// let mainQueue = DispatchQueue.test
  ///
  /// let store = TestStore(
  ///   initialState: SearchState(),
  ///   reducer: searchReducer,
  ///   environment: SearchEnvironment(
  ///     // Wrap the test scheduler in a type-erased scheduler
  ///     mainQueue: mainQueue.eraseToAnyScheduler(),
  ///     // Simulate a search response with one item
  ///     request: { ["Composable Architecture"] }
  ///   )
  /// )
  ///
  /// // Change the query
  /// await store.send(.searchFieldChanged("c") {
  ///   // Assert that state updates accordingly
  ///   $0.query = "c"
  /// }
  ///
  /// // Advance the queue by a period shorter than the debounce
  /// await mainQueue.advance(by: 0.25)
  ///
  /// // Change the query again
  /// await store.send(.searchFieldChanged("co") {
  ///   $0.query = "co"
  /// }
  ///
  /// // Advance the queue by a period shorter than the debounce
  /// await mainQueue.advance(by: 0.25)
  /// // Advance the scheduler to the debounce
  /// await scheduler.advance(by: 0.25)
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
  ///
  public final class TestStore<State, ScopedState, Action, ScopedAction, Environment> {
    /// The current environment.
    ///
    /// The environment can be modified throughout a test store's lifecycle in order to influence
    /// how it produces effects. This can be handy for testing flows that require a dependency
    /// to start in a failing state and then later change into a succeeding state:
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
    public var environment: Environment

    /// The current state.
    ///
    /// When read from a trailing closure assertion in ``send(_:_:file:line:)-7vwv9`` or
    /// ``receive(_:timeout:_:file:line:)-88eyr``, it will equal the `inout` state passed to the
    /// closure.
    public private(set) var state: State

    /// The timeout to await for in-flight effects.
    ///
    /// This is the default timeout used in all methods that take an optional timeout, such as
    /// ``send(_:_:file:line:)-7vwv9``, ``receive(_:timeout:_:file:line:)-88eyr`` and
    /// ``finish(timeout:file:line:)-53gi5``.
    public var timeout: UInt64

    private let file: StaticString
    private let fromScopedAction: (ScopedAction) -> Action
    private var line: UInt
    private var inFlightEffects: Set<LongLivingEffect> = []
    var receivedActions: [(action: Action, state: State)] = []
    private let reducer: Reducer<State, Action, Environment>
    private var store: Store<State, TestAction>!
    private let toScopedState: (State) -> ScopedState

    private init(
      environment: Environment,
      file: StaticString,
      fromScopedAction: @escaping (ScopedAction) -> Action,
      initialState: State,
      line: UInt,
      reducer: Reducer<State, Action, Environment>,
      toScopedState: @escaping (State) -> ScopedState
    ) {
      self.environment = environment
      self.file = file
      self.fromScopedAction = fromScopedAction
      self.line = line
      self.reducer = reducer
      self.state = initialState
      self.toScopedState = toScopedState
      self.timeout = 100 * NSEC_PER_MSEC

      self.store = Store(
        initialState: initialState,
        reducer: Reducer<State, TestAction, Void> { [unowned self] state, action, _ in
          let effects: Effect<Action, Never>
          switch action.origin {
          case let .send(scopedAction):
            effects = self.reducer.run(
              &state, self.fromScopedAction(scopedAction), self.environment)
            self.state = state

          case let .receive(action):
            effects = self.reducer.run(&state, action, self.environment)
            self.receivedActions.append((action, state))
          }

          let effect = LongLivingEffect(file: action.file, line: action.line)
          return
            effects
            .handleEvents(
              receiveSubscription: { [weak self] _ in self?.inFlightEffects.insert(effect) },
              receiveCompletion: { [weak self] _ in self?.inFlightEffects.remove(effect) },
              receiveCancel: { [weak self] in self?.inFlightEffects.remove(effect) }
            )
            .eraseToEffect { .init(origin: .receive($0), file: action.file, line: action.line) }

        },
        environment: ()
      )
    }

    #if swift(>=5.7)
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
    /// - Parameter nanoseconds: The amount of time to wait before asserting.
    @MainActor
    public func finish(
      timeout nanoseconds: UInt64? = nil,
      file: StaticString = #file,
      line: UInt = #line
    ) async {
      let nanoseconds = nanoseconds ?? self.timeout
      let start = DispatchTime.now().uptimeNanoseconds
      await Task.megaYield()
      while !self.inFlightEffects.isEmpty {
        guard start.distance(to: DispatchTime.now().uptimeNanoseconds) < nanoseconds
        else {
          let timeoutMessage =
            nanoseconds != self.self.timeout
            ? #"try increasing the duration of this assertion's "timeout""#
            : #"configure this assertion with an explicit "timeout""#
          let suggestion = """
            There are effects in-flight. If the effect that delivers this action uses a \
            scheduler (via "receive(on:)", "delay", "debounce", etc.), make sure that you wait \
            enough time for the scheduler to perform the effect. If you are using a test \
            scheduler, advance the scheduler so that the effects may complete, or consider using \
            an immediate scheduler to immediately perform the effect instead.

            If you are not yet using a scheduler, or can not use a scheduler, \(timeoutMessage).
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
      if !self.receivedActions.isEmpty {
        var actions = ""
        customDump(self.receivedActions.map(\.action), to: &actions)
        XCTFail(
          """
          The store received \(self.receivedActions.count) unexpected \
          action\(self.receivedActions.count == 1 ? "" : "s") after this one: …

          Unhandled actions: \(actions)
          """,
          file: self.file, line: self.line
        )
      }
      for effect in self.inFlightEffects {
        XCTFail(
          """
          An effect returned for this action is still running. It must complete before the end of \
          the test. …

          To fix, inspect any effects the reducer returns for this action and ensure that all of \
          them complete by the end of the test. There are a few reasons why an effect may not have \
          completed:

          • If using async/await in your effect, it may need a little bit of time to properly \
          finish. To fix you can simply perform "await store.finish()" at the end of your test.

          • If an effect uses a scheduler (via "receive(on:)", "delay", "debounce", etc.), make \
          sure that you wait enough time for the scheduler to perform the effect. If you are using \
          a test scheduler, advance the scheduler so that the effects may complete, or consider \
          using an immediate scheduler to immediately perform the effect instead.

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

    private struct LongLivingEffect: Hashable {
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

    private struct TestAction: CustomDebugStringConvertible {
      let origin: Origin
      let file: StaticString
      let line: UInt

      enum Origin {
        case send(ScopedAction)
        case receive(Action)
      }

      var debugDescription: String {
        switch self.origin {
        case let .send(action):
          return debugCaseOutput(action)

        case let .receive(action):
          return debugCaseOutput(action)
        }
      }
    }
  }

  extension TestStore where State == ScopedState, Action == ScopedAction {
    /// Initializes a test store from an initial state, a reducer, and an initial environment.
    ///
    /// - Parameters:
    ///   - initialState: The state to start the test from.
    ///   - reducer: A reducer.
    ///   - environment: The environment to start the test from.
    public convenience init(
      initialState: State,
      reducer: Reducer<State, Action, Environment>,
      environment: Environment,
      file: StaticString = #file,
      line: UInt = #line
    ) {
      self.init(
        environment: environment,
        file: file,
        fromScopedAction: { $0 },
        initialState: initialState,
        line: line,
        reducer: reducer,
        toScopedState: { $0 }
      )
    }
  }

  extension TestStore where ScopedState: Equatable {
    /// Sends an action to the store and asserts when state changes.
    ///
    /// This method suspends in order to allow any effects to start. For example, if you
    /// track an analytics event in a ``Effect/fireAndForget(priority:_:)`` when an action is sent,
    /// you can assert on that behavior immediately after awaiting `store.send`:
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
      if !self.receivedActions.isEmpty {
        var actions = ""
        customDump(self.receivedActions.map(\.action), to: &actions)
        XCTFail(
          """
          Must handle \(self.receivedActions.count) received \
          action\(self.receivedActions.count == 1 ? "" : "s") before sending an action: …

          Unhandled actions: \(actions)
          """,
          file: file, line: line
        )
      }
      var expectedState = self.toScopedState(self.state)
      let previousState = self.state
      let task = self.store.send(.init(origin: .send(action), file: file, line: line))
      await Task.megaYield()
      do {
        let currentState = self.state
        self.state = previousState
        defer { self.state = currentState }

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
      await Task.megaYield()
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
      if !self.receivedActions.isEmpty {
        var actions = ""
        customDump(self.receivedActions.map(\.action), to: &actions)
        XCTFail(
          """
          Must handle \(self.receivedActions.count) received \
          action\(self.receivedActions.count == 1 ? "" : "s") before sending an action: …

          Unhandled actions: \(actions)
          """,
          file: file, line: line
        )
      }
      var expectedState = self.toScopedState(self.state)
      let previousState = self.state
      let task = self.store.send(.init(origin: .send(action), file: file, line: line))
      do {
        let currentState = self.state
        self.state = previousState
        defer { self.state = currentState }

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
      guard !self.receivedActions.isEmpty else {
        XCTFail(
          """
          Expected to receive an action, but received none.
          """,
          file: file, line: line
        )
        return
      }
      let (receivedAction, state) = self.receivedActions.removeFirst()
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
      self.state = state
      if "\(self.file)" == "\(file)" {
        self.line = line
      }
    }

    #if swift(>=5.7)
      /// Asserts an action was received from an effect and asserts how the state changes.
      ///
      /// - Parameters:
      ///   - expectedAction: An action expected from an effect.
      ///   - duration: The amount of time to wait for the expected action.
      ///   - updateExpectingResult: A closure that asserts state changed by sending the action to
      ///     the store. The mutable state sent to this closure must be modified to match the state
      ///     of the store after processing the given action. Do not provide a closure if no change
      ///     is expected.
      @MainActor
      @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
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

      guard !self.inFlightEffects.isEmpty
      else {
        { self.receive(expectedAction, updateExpectingResult, file: file, line: line) }()
        return
      }

      await Task.megaYield()
      let start = DispatchTime.now().uptimeNanoseconds
      while !Task.isCancelled {
        await Task.detached(priority: .low) { await Task.yield() }.value

        guard self.receivedActions.isEmpty
        else { break }

        guard start.distance(to: DispatchTime.now().uptimeNanoseconds) < nanoseconds
        else {
          let suggestion: String
          if self.inFlightEffects.isEmpty {
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
              scheduler (via "receive(on:)", "delay", "debounce", etc.), make sure that you wait \
              enough time for the scheduler to perform the effect. If you are using a test \
              scheduler, advance the scheduler so that the effects may complete, or consider using \
              an immediate scheduler to immediately perform the effect instead.

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
    ) -> TestStore<State, S, Action, A, Environment> {
      .init(
        environment: self.environment,
        file: self.file,
        fromScopedAction: { self.fromScopedAction(fromScopedAction($0)) },
        initialState: self.store.state.value,
        line: self.line,
        reducer: self.reducer,
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
    ) -> TestStore<State, S, Action, ScopedAction, Environment> {
      self.scope(state: toScopedState, action: { $0 })
    }
  }

  /// The type returned from ``TestStore/send(_:_:file:line:)-7vwv9`` that represents the lifecycle
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
  /// See ``TestStore/finish(timeout:file:line:)-53gi5`` for the ability to await all in-flight
  /// effects in the test store.
  ///
  /// See ``ViewStoreTask`` for the analog provided to ``ViewStore``.
  public struct TestStoreTask: Hashable, Sendable {
    fileprivate let rawValue: Task<Void, Never>?
    fileprivate let timeout: UInt64

    /// Cancels the underlying task and waits for it to finish.
    public func cancel() async {
      self.rawValue?.cancel()
      await self.rawValue?.cancellableValue
    }

    #if swift(>=5.7)
      @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
      /// Asserts the underlying task finished.
      ///
      /// - Parameter duration: The amount of time to wait before asserting.
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
          If this task delivers its action using a scheduler (via "sleep(for:)", \
          "timer(interval:)", etc.), make sure that you wait enough time for the scheduler to \
          perform its work. If you are using a test scheduler, advance the scheduler so that the \
          effects may complete, or consider using an immediate scheduler to immediately perform \
          the effect instead.

          If you are not yet using a scheduler, or can not use a scheduler, \(timeoutMessage).
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

  extension Task where Success == Never, Failure == Never {
    static func megaYield(count: Int = 3) async {
      for _ in 1...count {
        await Task<Void, Never>.detached(priority: .low) { await Task.yield() }.value
      }
    }
  }

  #if swift(>=5.7)
    @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
    extension Duration {
      fileprivate var nanoseconds: UInt64 {
        UInt64(self.components.seconds) * NSEC_PER_SEC
          + UInt64(self.components.attoseconds) / 1_000_000_000
      }
    }
  #endif
#endif
