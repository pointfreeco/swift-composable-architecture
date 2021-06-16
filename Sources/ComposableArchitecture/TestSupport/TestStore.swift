#if DEBUG
  import Combine
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
  ///
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
  ///       initialState: .init(count: 0),     // GIVEN counter state of 0
  ///       reducer: counterReducer,
  ///       environment: ()
  ///     )
  ///     store.send(.incrementButtonTapped) { // WHEN the increment button is tapped
  ///       $0.count = 1                       // THEN the count should be 1
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
  /// ``Effect/debounce(id:for:scheduler:options:)`` operator to wait for the user to stop typing
  /// before making a network request:
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
  ///     struct SearchId: Hashable {}
  ///
  ///     switch action {
  ///     case let .queryChanged(query):
  ///       state.query = query
  ///       return environment.request(self.query)
  ///         .debounce(id: SearchId(), for: 0.5, scheduler: environment.mainQueue)
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
  public final class TestStore<State, LocalState, Action: Equatable, LocalAction, Environment> {
    public var environment: Environment

    private let file: StaticString
    private let fromLocalAction: (LocalAction) -> Action
    private var line: UInt
    private var longLivingEffects: Set<LongLivingEffect> = []
    private var receivedActions: [(action: Action, state: State)] = []
    private let reducer: Reducer<State, Action, Environment>
    private var snapshotState: State
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
      self.snapshotState = initialState
      self.toLocalState = toLocalState

      self.store = Store(
        initialState: initialState,
        reducer: Reducer<State, TestAction, Void> { [unowned self] state, action, _ in
          let effects: Effect<Action, Never>
          switch action.origin {
          case let .send(localAction):
            effects = self.reducer.run(&state, self.fromLocalAction(localAction), self.environment)
            self.snapshotState = state

          case let .receive(action):
            effects = self.reducer.run(&state, action, self.environment)
            self.receivedActions.append((action, state))
          }

          let effect = LongLivingEffect(file: action.file, line: action.line)
          return
            effects
            .handleEvents(
              receiveSubscription: { [weak self] _ in
                self?.longLivingEffects.insert(effect)
              },
              receiveCompletion: { [weak self] _ in self?.longLivingEffects.remove(effect) },
              receiveCancel: { [weak self] in self?.longLivingEffects.remove(effect) }
            )
            .map { .init(origin: .receive($0), file: action.file, line: action.line) }
            .eraseToEffect()

        },
        environment: ()
      )
    }

    deinit {
      self.completed()
    }

    private func completed() {
      if !self.receivedActions.isEmpty {
        XCTFail(
          """
          The store received \(self.receivedActions.count) unexpected \
          action\(self.receivedActions.count == 1 ? "" : "s") after this one: …

          Unhandled actions: \(debugOutput(self.receivedActions.map { $0.action }))
          """,
          file: self.file, line: self.line
        )
      }
      for effect in self.longLivingEffects {
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
    public func send(
      _ action: LocalAction,
      file: StaticString = #file,
      line: UInt = #line,
      _ update: @escaping (inout LocalState) throws -> Void = { _ in }
    ) {
      if !self.receivedActions.isEmpty {
        XCTFail(
          """
          Must handle \(self.receivedActions.count) received \
          action\(self.receivedActions.count == 1 ? "" : "s") before sending an action: …

          Unhandled actions: \(debugOutput(self.receivedActions.map { $0.action }))
          """,
          file: file, line: line
        )
      }
      var expectedState = self.toLocalState(self.snapshotState)
      ViewStore(
        self.store.scope(
          state: self.toLocalState,
          action: { .init(origin: .send($0), file: file, line: line) }
        )
      )
      .send(action)
      do {
        try update(&expectedState)
      } catch {
        XCTFail("Threw error: \(error)", file: file, line: line)
      }
      self.expectedStateShouldMatch(
        expected: expectedState,
        actual: self.toLocalState(self.snapshotState),
        file: file,
        line: line
      )
      if "\(self.file)" == "\(file)" {
        self.line = line
      }
    }

    public func receive(
      _ expectedAction: Action,
      file: StaticString = #file,
      line: UInt = #line,
      _ update: @escaping (inout LocalState) throws -> Void = { _ in }
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
        let diff =
          debugDiff(expectedAction, receivedAction)
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

          \(diff)
          """,
          file: file, line: line
        )
      }
      var expectedState = self.toLocalState(self.snapshotState)
      do {
        try update(&expectedState)
      } catch {
        XCTFail("Threw error: \(error)", file: file, line: line)
      }
      expectedStateShouldMatch(
        expected: expectedState,
        actual: self.toLocalState(state),
        file: file,
        line: line
      )
      snapshotState = state
      if "\(self.file)" == "\(file)" {
        self.line = line
      }
    }

    /// Asserts against a script of actions.
    public func assert(
      _ steps: Step...,
      file: StaticString = #file,
      line: UInt = #line
    ) {
      assert(steps, file: file, line: line)
    }

    /// Asserts against an array of actions.
    public func assert(
      _ steps: [Step],
      file: StaticString = #file,
      line: UInt = #line
    ) {

      func assert(step: Step) {
        switch step.type {
        case let .send(action, update):
          self.send(action, file: step.file, line: step.line, update)

        case let .receive(expectedAction, update):
          self.receive(expectedAction, file: step.file, line: step.line, update)

        case let .environment(work):
          if !self.receivedActions.isEmpty {
            XCTFail(
              """
              Must handle \(self.receivedActions.count) received \
              action\(self.receivedActions.count == 1 ? "" : "s") before performing this work: …

              Unhandled actions: \(debugOutput(self.receivedActions.map { $0.action }))
              """,
              file: step.file, line: step.line
            )
          }
          do {
            try work(&self.environment)
          } catch {
            XCTFail("Threw error: \(error)", file: step.file, line: step.line)
          }

        case let .do(work):
          if !receivedActions.isEmpty {
            XCTFail(
              """
              Must handle \(self.receivedActions.count) received \
              action\(self.receivedActions.count == 1 ? "" : "s") before performing this work: …

              Unhandled actions: \(debugOutput(self.receivedActions.map { $0.action }))
              """,
              file: step.file, line: step.line
            )
          }
          do {
            try work()
          } catch {
            XCTFail("Threw error: \(error)", file: step.file, line: step.line)
          }

        case let .sequence(subSteps):
          subSteps.forEach(assert(step:))
        }
      }

      steps.forEach(assert(step:))

      self.completed()
    }

    private func expectedStateShouldMatch(
      expected: LocalState,
      actual: LocalState,
      file: StaticString,
      line: UInt
    ) {
      if expected != actual {
        let diff =
          debugDiff(expected, actual)
          .map { "\($0.indent(by: 4))\n\n(Expected: −, Actual: +)" }
          ?? """
          Expected:
          \(String(describing: expected).indent(by: 2))

          Actual:
          \(String(describing: actual).indent(by: 2))
          """

        XCTFail(
          """
          State change does not match expectation: …

          \(diff)
          """,
          file: file,
          line: line
        )
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

    /// A single step of a ``TestStore`` assertion.
    public struct Step {
      fileprivate let type: StepType
      fileprivate let file: StaticString
      fileprivate let line: UInt

      private init(
        _ type: StepType,
        file: StaticString = #file,
        line: UInt = #line
      ) {
        self.type = type
        self.file = file
        self.line = line
      }

      /// A step that describes an action sent to a store and asserts against how the store's state
      /// is expected to change.
      ///
      /// - Parameters:
      ///   - action: An action to send to the test store.
      ///   - update: A function that describes how the test store's state is expected to change.
      /// - Returns: A step that describes an action sent to a store and asserts against how the
      ///   store's state is expected to change.
      public static func send(
        _ action: LocalAction,
        file: StaticString = #file,
        line: UInt = #line,
        _ update: @escaping (inout LocalState) throws -> Void = { _ in }
      ) -> Step {
        Step(.send(action, update), file: file, line: line)
      }

      /// A step that describes an action received by an effect and asserts against how the store's
      /// state is expected to change.
      ///
      /// - Parameters:
      ///   - action: An action the test store should receive by evaluating an effect.
      ///   - update: A function that describes how the test store's state is expected to change.
      /// - Returns: A step that describes an action received by an effect and asserts against how
      ///   the store's state is expected to change.
      public static func receive(
        _ action: Action,
        file: StaticString = #file,
        line: UInt = #line,
        _ update: @escaping (inout LocalState) throws -> Void = { _ in }
      ) -> Step {
        Step(.receive(action, update), file: file, line: line)
      }

      /// A step that updates a test store's environment.
      ///
      /// - Parameter update: A function that updates the test store's environment for subsequent
      ///   steps.
      /// - Returns: A step that updates a test store's environment.
      public static func environment(
        file: StaticString = #file,
        line: UInt = #line,
        _ update: @escaping (inout Environment) throws -> Void
      ) -> Step {
        Step(.environment(update), file: file, line: line)
      }

      /// A step that captures some work to be done between assertions
      ///
      /// - Parameter work: A function that is called between steps.
      /// - Returns: A step that captures some work to be done between assertions.
      public static func `do`(
        file: StaticString = #file,
        line: UInt = #line,
        _ work: @escaping () throws -> Void
      ) -> Step {
        Step(.do(work), file: file, line: line)
      }

      /// A step that captures a sub-sequence of steps.
      ///
      /// - Parameter steps: An array of ``TestStore/Step``
      /// - Returns: A step that captures a sub-sequence of steps.
      public static func sequence(
        _ steps: [Step],
        file: StaticString = #file,
        line: UInt = #line
      ) -> Step {
        Step(.sequence(steps), file: file, line: line)
      }

      /// A step that captures a sub-sequence of steps.
      ///
      /// - Parameter steps: A variadic list of ``TestStore/Step``
      /// - Returns: A step that captures a sub-sequence of steps.
      public static func sequence(
        _ steps: Step...,
        file: StaticString = #file,
        line: UInt = #line
      ) -> Step {
        Step(.sequence(steps), file: file, line: line)
      }

      fileprivate indirect enum StepType {
        case send(LocalAction, (inout LocalState) throws -> Void)
        case receive(Action, (inout LocalState) throws -> Void)
        case environment((inout Environment) throws -> Void)
        case `do`(() throws -> Void)
        case sequence([Step])
      }
    }

    private struct TestAction {
      let origin: Origin
      let file: StaticString
      let line: UInt

      enum Origin {
        case send(LocalAction)
        case receive(Action)
      }
    }
  }
#endif
