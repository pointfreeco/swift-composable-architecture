#if DEBUG
  import Combine
  import Foundation

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
  ///     struct CounterState {
  ///       var count = 0
  ///     }
  ///
  ///     enum CounterAction: Equatable {
  ///       case decrementButtonTapped
  ///       case incrementButtonTapped
  ///     }
  ///
  ///     let counterReducer = Reducer<CounterState, CounterAction, Void> { state, action, _ in
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
  ///
  /// One can assert against its behavior over time:
  ///
  ///     class CounterTests: XCTestCase {
  ///       func testCounter() {
  ///         let store = TestStore(
  ///           initialState: .init(count: 0),  // GIVEN counter state of 0
  ///           reducer: counterReducer,
  ///           environment: ()
  ///         )
  ///
  ///         store.assert(
  ///           .send(.incrementButtonTapped) { // WHEN the increment button is tapped
  ///             $0.count = 1                  // THEN the count should be 1
  ///           }
  ///         )
  ///       }
  ///     }
  ///
  /// Note that in the trailing closure of `.send(.incrementButtonTapped)` we are given a single
  /// mutable value of the state before the action was sent, and it is our job to mutate the value
  /// to match the state after the action was sent. In this case the `count` field changes to `1`.
  ///
  /// For a more complex example, consider the following bare-bones search feature that uses the
  /// `.debounce` operator to wait for the user to stop typing before making a network request:
  ///
  ///     struct SearchState: Equatable {
  ///       var query = ""
  ///       var results: [String] = []
  ///     }
  ///
  ///     enum SearchAction: Equatable {
  ///       case queryChanged(String)
  ///       case response([String])
  ///     }
  ///
  ///     struct SearchEnvironment {
  ///       var mainQueue: AnySchedulerOf<DispatchQueue>
  ///       var request: (String) -> Effect<[String], Never>
  ///     }
  ///
  ///     let searchReducer = Reducer<SearchState, SearchAction, SearchEnvironment> {
  ///       state, action, environment in
  ///
  ///         struct SearchId: Hashable {}
  ///
  ///         switch action {
  ///         case let .queryChanged(query):
  ///           state.query = query
  ///           return environment.request(self.query)
  ///             .debounce(id: SearchId(), for: 0.5, scheduler: environment.mainQueue)
  ///
  ///         case let .response(results):
  ///           state.results = results
  ///           return .none
  ///         }
  ///     }
  ///
  /// It can be fully tested by controlling the environment's scheduler and effect:
  ///
  ///     // Create a test dispatch scheduler to control the timing of effects
  ///     let scheduler = DispatchQueue.testScheduler
  ///
  ///     let store = TestStore(
  ///       initialState: SearchState(),
  ///       reducer: searchReducer,
  ///       environment: SearchEnvironment(
  ///         // Wrap the test scheduler in a type-erased scheduler
  ///         mainQueue: scheduler.eraseToAnyScheduler(),
  ///         // Simulate a search response with one item
  ///         request: { _ in Effect(value: ["Composable Architecture"]) }
  ///       )
  ///     )
  ///     store.assert(
  ///       // Change the query
  ///       .send(.searchFieldChanged("c") {
  ///         // Assert that state updates accordingly
  ///         $0.query = "c"
  ///       },
  ///
  ///       // Advance the scheduler by a period shorter than the debounce
  ///       .do { scheduler.advance(by: 0.25) },
  ///
  ///       // Change the query again
  ///       .send(.searchFieldChanged("co") {
  ///         $0.query = "co"
  ///       },
  ///
  ///       // Advance the scheduler by a period shorter than the debounce
  ///       .do { scheduler.advance(by: 0.25) },
  ///       // Advance the scheduler to the debounce
  ///       .do { scheduler.advance(by: 0.25) },
  ///
  ///       // Assert that the expected response is received
  ///       .receive(.response(["Composable Architecture"])) {
  ///         // Assert that state updates accordingly
  ///         $0.results = ["Composable Architecture"]
  ///       }
  ///     )
  ///
  /// This test is proving that the debounced network requests are correctly canceled when we do not
  /// wait longer than the 0.5 seconds, because if it wasn't and it delivered an action when we did
  /// not expect it would cause a test failure.
  ///
  public final class TestStore<State, LocalState, Action: Equatable, LocalAction, Environment> {
    private var environment: Environment
    private let fromLocalAction: (LocalAction) -> Action
    private let reducer: Reducer<State, Action, Environment>
    private var state: State
    private let toLocalState: (State) -> LocalState

    private init(
      environment: Environment,
      fromLocalAction: @escaping (LocalAction) -> Action,
      initialState: State,
      reducer: Reducer<State, Action, Environment>,
      toLocalState: @escaping (State) -> LocalState
    ) {
      self.environment = environment
      self.fromLocalAction = fromLocalAction
      self.state = initialState
      self.reducer = reducer
      self.toLocalState = toLocalState
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
      environment: Environment
    ) {
      self.init(
        environment: environment,
        fromLocalAction: { $0 },
        initialState: initialState,
        reducer: reducer,
        toLocalState: { $0 }
      )
    }
  }

  extension TestStore where LocalState: Equatable {
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
      var receivedActions: [(action: Action, state: State)] = []
      var longLivingEffects: Set<LongLivingEffect> = []
      var snapshotState = self.state

      let store = Store(
        initialState: self.state,
        reducer: Reducer<State, TestAction, Void> { state, action, _ in
          let effects: Effect<Action, Never>
          switch action.origin {
          case let .send(localAction):
            effects = self.reducer.run(&state, self.fromLocalAction(localAction), self.environment)
            snapshotState = state

          case let .receive(action):
            effects = self.reducer.run(&state, action, self.environment)
            receivedActions.append((action, state))
          }

          let effect = LongLivingEffect(file: action.file, line: action.line)
          return
            effects
            .handleEvents(
              receiveSubscription: { _ in longLivingEffects.insert(effect) },
              receiveCompletion: { _ in longLivingEffects.remove(effect) },
              receiveCancel: { longLivingEffects.remove(effect) }
            )
            .map { .init(origin: .receive($0), file: action.file, line: action.line) }
            .eraseToEffect()
        },
        environment: ()
      )
      defer { self.state = store.state.value }

      func assert(step: Step) {
        var expectedState = toLocalState(snapshotState)

        func expectedStateShouldMatch(actualState: LocalState) {
          if expectedState != actualState {
            let diff =
              debugDiff(expectedState, actualState)
              .map { "\($0.indent(by: 4))\n\n(Expected: −, Actual: +)" }
              ?? """
              Expected:
              \(String(describing: expectedState).indent(by: 2))

              Actual:
              \(String(describing: actualState).indent(by: 2))
              """

            _XCTFail(
              """
              State change does not match expectation: …

              \(diff)
              """,
              file: step.file,
              line: step.line
            )
          }
        }

        switch step.type {
        case let .send(action, update):
          if !receivedActions.isEmpty {
            _XCTFail(
              """
              Must handle \(receivedActions.count) received \
              action\(receivedActions.count == 1 ? "" : "s") before sending an action: …

              Unhandled actions: \(debugOutput(receivedActions.map { $0.action }))
              """,
              file: step.file, line: step.line
            )
          }
          ViewStore(
            store.scope(
              state: self.toLocalState,
              action: { .init(origin: .send($0), file: step.file, line: step.line) }
            )
          )
          .send(action)
          do {
            try update(&expectedState)
          } catch {
            _XCTFail("Threw error: \(error)", file: step.file, line: step.line)
          }
          expectedStateShouldMatch(actualState: toLocalState(snapshotState))

        case let .receive(expectedAction, update):
          guard !receivedActions.isEmpty else {
            _XCTFail(
              """
              Expected to receive an action, but received none.
              """,
              file: step.file, line: step.line
            )
            break
          }
          let (receivedAction, state) = receivedActions.removeFirst()
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

            _XCTFail(
              """
              Received unexpected action: …

              \(diff)
              """,
              file: step.file, line: step.line
            )
          }
          do {
            try update(&expectedState)
          } catch {
            _XCTFail("Threw error: \(error)", file: step.file, line: step.line)
          }
          expectedStateShouldMatch(actualState: toLocalState(state))
          snapshotState = state

        case let .environment(work):
          if !receivedActions.isEmpty {
            _XCTFail(
              """
              Must handle \(receivedActions.count) received \
              action\(receivedActions.count == 1 ? "" : "s") before performing this work: …

              Unhandled actions: \(debugOutput(receivedActions.map { $0.action }))
              """,
              file: step.file, line: step.line
            )
          }
          do {
            try work(&self.environment)
          } catch {
            _XCTFail("Threw error: \(error)", file: step.file, line: step.line)
          }

        case let .do(work):
          if !receivedActions.isEmpty {
            _XCTFail(
              """
              Must handle \(receivedActions.count) received \
              action\(receivedActions.count == 1 ? "" : "s") before performing this work: …

              Unhandled actions: \(debugOutput(receivedActions.map { $0.action }))
              """,
              file: step.file, line: step.line
            )
          }
          do {
            try work()
          } catch {
            _XCTFail("Threw error: \(error)", file: step.file, line: step.line)
          }

        case let .sequence(subSteps):
          subSteps.forEach(assert(step:))
        }
      }

      steps.forEach(assert(step:))

      if !receivedActions.isEmpty {
        _XCTFail(
          """
          Received \(receivedActions.count) unexpected \
          action\(receivedActions.count == 1 ? "" : "s"): …

          Unhandled actions: \(debugOutput(receivedActions.map { $0.action }))
          """,
          file: file, line: line
        )
      }

      for effect in longLivingEffects {
        _XCTFail(
          """
          An effect returned for this action is still running. It must complete before the end of \
          the assertion. …

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
        fromLocalAction: { self.fromLocalAction(fromLocalAction($0)) },
        initialState: self.state,
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

    /// A single step of a `TestStore` assertion.
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
      /// - Parameter steps: An array of `Step`
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
      /// - Parameter steps: A variadic list of `Step`
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

  // NB: Dynamically load XCTest to prevent leaking its symbols into our library code.
  private func _XCTFail(_ message: String = "", file: StaticString = #file, line: UInt = #line) {
    guard
      let _XCTFailureHandler = _XCTFailureHandler,
      let _XCTCurrentTestCase = _XCTCurrentTestCase
    else {
      assertionFailure(
        """
        Couldn't load XCTest. Are you using a test store in application code?"
        """,
        file: file,
        line: line
      )
      return
    }

    _XCTFailureHandler(_XCTCurrentTestCase(), true, "\(file)", line, message, nil)
  }

  private typealias XCTCurrentTestCase = @convention(c) () -> AnyObject
  private typealias XCTFailureHandler = @convention(c) (
    AnyObject, Bool, UnsafePointer<CChar>, UInt, String, String?
  ) -> Void

  private let _XCTest = NSClassFromString("XCTest")
    .flatMap(Bundle.init(for:))
    .flatMap({ $0.executablePath })
    .flatMap({ dlopen($0, RTLD_NOW) })

  private let _XCTFailureHandler =
    _XCTest
    .flatMap { dlsym($0, "_XCTFailureHandler") }
    .map({ unsafeBitCast($0, to: XCTFailureHandler.self) })

  private let _XCTCurrentTestCase =
    _XCTest
    .flatMap { dlsym($0, "_XCTCurrentTestCase") }
    .map({ unsafeBitCast($0, to: XCTCurrentTestCase.self) })
#endif
