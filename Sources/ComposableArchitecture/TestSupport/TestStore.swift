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
  /// class CounterTests: XCTestCase {
  ///   func testCounter() {
  ///     let store = TestStore(
  ///       initialState: .init(count: 0),      // Given a counter state of 0
  ///       reducer: counterReducer,
  ///       environment: ()
  ///     )
  ///     store.send(.incrementButtonTapped) {  // When the increment button is tapped
  ///       $0.count = 1                        // Then the count should be 1
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
  ///   var request: (String) -> Effect<[String], Never>
  /// }
  ///
  /// let searchReducer = Reducer<SearchState, SearchAction, SearchEnvironment> {
  ///   state, action, environment in
  ///
  ///     enum SearchId {}
  ///
  ///     switch action {
  ///     case let .queryChanged(query):
  ///       state.query = query
  ///       return environment.request(self.query)
  ///         .debounce(id: SearchId.self, for: 0.5, scheduler: environment.mainQueue)
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
  /// let scheduler = DispatchQueue.test
  ///
  /// let store = TestStore(
  ///   initialState: SearchState(),
  ///   reducer: searchReducer,
  ///   environment: SearchEnvironment(
  ///     // Wrap the test scheduler in a type-erased scheduler
  ///     mainQueue: scheduler.eraseToAnyScheduler(),
  ///     // Simulate a search response with one item
  ///     request: { _ in Effect(value: ["Composable Architecture"]) }
  ///   )
  /// )
  ///
  /// // Change the query
  /// store.send(.searchFieldChanged("c") {
  ///   // Assert that state updates accordingly
  ///   $0.query = "c"
  /// }
  ///
  /// // Advance the scheduler by a period shorter than the debounce
  /// scheduler.advance(by: 0.25)
  ///
  /// // Change the query again
  /// store.send(.searchFieldChanged("co") {
  ///   $0.query = "co"
  /// }
  ///
  /// // Advance the scheduler by a period shorter than the debounce
  /// scheduler.advance(by: 0.25)
  /// // Advance the scheduler to the debounce
  /// scheduler.advance(by: 0.25)
  ///
  /// // Assert that the expected response is received
  /// store.receive(.response(["Composable Architecture"])) {
  ///   // Assert that state updates accordingly
  ///   $0.results = ["Composable Architecture"]
  /// }
  /// ```
  ///
  /// This test is proving that the debounced network requests are correctly canceled when we do not
  /// wait longer than the 0.5 seconds, because if it wasn't and it delivered an action when we did
  /// not expect it would cause a test failure.
  ///
  public final class TestStore<State, LocalState, Action, LocalAction, Environment> {
    /// The current environment.
    ///
    /// The environment can be modified throughout a test store's lifecycle in order to influence
    /// how it produces effects.
    public var environment: Environment

    /// The current state.
    ///
    /// When read from a trailing closure assertion in ``send(_:_:file:line:)`` or
    /// ``receive(_:_:file:line:)``, it will equal the `inout` state passed to the closure.
    public private(set) var state: State

    private let file: StaticString
    private let fromLocalAction: (LocalAction) -> Action
    private var line: UInt
    private var inFlightEffects: Set<LongLivingEffect> = []
    var receivedActions: [(action: Action, state: State)] = []
    private let reducer: Reducer<State, Action, Environment>
    private var store: Store<State, TestAction>!
    private let toLocalState: (State) -> LocalState

    private init(
      environment: Environment,
      file: StaticString,
      fromLocalAction: @escaping (LocalAction) -> Action,
      initialState: State,
      line: UInt,
      reducer: Reducer<State, Action, Environment>,
      toLocalState: @escaping (State) -> LocalState
    ) {
      self.environment = environment
      self.file = file
      self.fromLocalAction = fromLocalAction
      self.line = line
      self.reducer = reducer
      self.state = initialState
      self.toLocalState = toLocalState

      self.store = Store(
        initialState: initialState,
        reducer: Reducer<State, TestAction, Void> { [unowned self] state, action, _ in
          let effects: Effect<Action, Never>
          switch action.origin {
          case let .send(localAction):
            effects = self.reducer.run(&state, self.fromLocalAction(localAction), self.environment)
            self.state = state

          case let .receive(action):
            effects = self.reducer.run(&state, action, self.environment)
            self.receivedActions.append((action, state))
          }

          let effect = LongLivingEffect(file: action.file, line: action.line)
          return
            effects
            .handleEvents(
              receiveSubscription: { [weak self] _ in
                self?.inFlightEffects.insert(effect)
              },
              receiveCompletion: { [weak self] _ in self?.inFlightEffects.remove(effect) },
              receiveCancel: { [weak self] in self?.inFlightEffects.remove(effect) }
            )
            .eraseToEffect { .init(origin: .receive($0), file: action.file, line: action.line) }

        },
        environment: ()
      )
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
        case send(LocalAction)
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

  extension TestStore where State == LocalState, Action == LocalAction {
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
        fromLocalAction: { $0 },
        initialState: initialState,
        line: line,
        reducer: reducer,
        toLocalState: { $0 }
      )
    }
  }

  extension TestStore where LocalState: Equatable {
    /// Sends an action to the store and asserts when state changes.
    ///
    /// - Parameters:
    ///   - action: An action.
    ///   - updateExpectingResult: A closure that asserts state changed by sending the action to the
    ///     store. The mutable state sent to this closure must be modified to match the state of the
    ///     store after processing the given action. Do not provide a closure if no change is
    ///     expected.
    public func send(
      _ action: LocalAction,
      _ updateExpectingResult: ((inout LocalState) throws -> Void)? = nil,
      file: StaticString = #file,
      line: UInt = #line
    ) {
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
      var expectedState = self.toLocalState(self.state)
      let previousState = self.state
      self.store.send(.init(origin: .send(action), file: file, line: line))
      do {
        let currentState = self.state
        self.state = previousState
        defer { self.state = currentState }

        try self.expectedStateShouldMatch(
          expected: &expectedState,
          actual: self.toLocalState(currentState),
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
    }

    private func expectedStateShouldMatch(
      expected: inout LocalState,
      actual: LocalState,
      modify: ((inout LocalState) throws -> Void)? = nil,
      file: StaticString,
      line: UInt
    ) throws {
      guard let modify = modify else { return }
      let current = expected
      try modify(&expected)

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

        XCTFail(
          """
          A state change does not match expectation: …

          \(difference)
          """,
          file: file,
          line: line
        )
      } else if expected == current {
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

  extension TestStore where LocalState: Equatable, Action: Equatable {
    /// Asserts an action was received from an effect and asserts when state changes.
    ///
    /// - Parameters:
    ///   - expectedAction: An action expected from an effect.
    ///   - updateExpectingResult: A closure that asserts state changed by sending the action to the
    ///     store. The mutable state sent to this closure must be modified to match the state of the
    ///     store after processing the given action. Do not provide a closure if no change is
    ///     expected.
    public func receive(
      _ expectedAction: Action,
      _ updateExpectingResult: ((inout LocalState) throws -> Void)? = nil,
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
        let difference =
          diff(expectedAction, receivedAction, format: .proportional)
          .map { "\($0.indent(by: 4))\n\n(Expected: −, Received: +)" }
          ?? """
          Expected:
          \(String(describing: expectedAction).indent(by: 2))

          Received:
          \(String(describing: receivedAction).indent(by: 2))
          """

        XCTFail(
          """
          Received unexpected action: …

          \(difference)
          """,
          file: file, line: line
        )
      }
      var expectedState = self.toLocalState(self.state)
      do {
        try expectedStateShouldMatch(
          expected: &expectedState,
          actual: self.toLocalState(state),
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
  }

  extension TestStore {
    /// Scopes a store to assert against more local state and actions.
    ///
    /// Useful for testing view store-specific state and actions.
    ///
    /// - Parameters:
    ///   - toLocalState: A function that transforms the reducer's state into more local state. This
    ///     state will be asserted against as it is mutated by the reducer. Useful for testing view
    ///     store state transformations.
    ///   - fromLocalAction: A function that wraps a more local action in the reducer's action.
    ///     Local actions can be "sent" to the store, while any reducer action may be received.
    ///     Useful for testing view store action transformations.
    public func scope<S, A>(
      state toLocalState: @escaping (LocalState) -> S,
      action fromLocalAction: @escaping (A) -> LocalAction
    ) -> TestStore<State, S, Action, A, Environment> {
      .init(
        environment: self.environment,
        file: self.file,
        fromLocalAction: { self.fromLocalAction(fromLocalAction($0)) },
        initialState: self.store.state.value,
        line: self.line,
        reducer: self.reducer,
        toLocalState: { toLocalState(self.toLocalState($0)) }
      )
    }

    /// Scopes a store to assert against more local state.
    ///
    /// Useful for testing view store-specific state.
    ///
    /// - Parameter toLocalState: A function that transforms the reducer's state into more local
    ///   state. This state will be asserted against as it is mutated by the reducer. Useful for
    ///   testing view store state transformations.
    public func scope<S>(
      state toLocalState: @escaping (LocalState) -> S
    ) -> TestStore<State, S, Action, LocalAction, Environment> {
      self.scope(state: toLocalState, action: { $0 })
    }
  }
#endif
