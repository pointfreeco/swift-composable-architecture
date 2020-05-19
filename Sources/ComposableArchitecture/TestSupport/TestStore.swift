#if DEBUG
  import Combine
  import Foundation

  /// A testable runtime for a reducer.
  ///
  /// For example, given a simple counter reducer:
  ///
  ///     enum CounterAction: Equatable {
  ///       case decrementButtonTapped
  ///       case incrementButtonTapped
  ///     }
  ///
  ///     let counterReducer = Reducer<Int, CounterAction, Void> { count, action, _ in
  ///       switch action {
  ///       case .decrementButtonTapped:
  ///         count -= 1
  ///         return .none
  ///       case .incrementButtonTapped:
  ///         count += 1
  ///         return .none
  ///       }
  ///     }
  ///
  /// One can assert against its behavior over time:
  ///
  ///     class CounterTests: XCTestCase {
  ///       func testCounter() {
  ///         let store = TestStore(
  ///           initialState: 0,                // GIVEN counter state of 0
  ///           reducer: counterReducer,
  ///           environment: ()
  ///         )
  ///
  ///         store.assert(
  ///           .send(.incrementButtonTapped) { // WHEN the increment button is tapped
  ///             $0 = 1                        // THEN the count should be 1
  ///           }
  ///         )
  ///       }
  ///     }
  ///
  /// For a more complex example, including timing and effects, consider the following bare-bones
  /// search feature:
  ///
  ///     struct SearchState: Equatable {
  ///       var query = ""
  ///       var results: [String] = []
  ///     }
  ///     enum SearchAction: Equatable {
  ///       case queryChanged(String)
  ///       case response([String])
  ///     }
  ///     struct SearchEnvironment {
  ///       var mainQueue: AnySchedulerOf<DispatchQueue>
  ///       var request: (String) -> Effect<[String], Never>
  ///     }
  ///     let searchReducer = Reducer<
  ///       SearchState, SearchAction, SearchEnvironment
  ///     > { state, action, environment in
  ///
  ///       // A local identifier for debouncing and canceling the search request effect.
  ///       struct SearchId: Hashable {}
  ///
  ///       switch action {
  ///       case let .queryChanged(query):
  ///         state.query = query
  ///         return environment.request(self.query)
  ///           .debounce(id: SearchId(), for: 0.5, scheduler: environment.mainQueue)
  ///       case let .response(results):
  ///         state.results = results
  ///         return .none
  ///       }
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
  ///       // Advance the scheduler by a period shorter than the debounce
  ///       .do { scheduler.advance(by: 0.25) },
  ///       // Change the query again
  ///       .send(.searchFieldChanged("co") {
  ///         $0.query = "co"
  ///       },
  ///       // Advance the scheduler by a period shorter than the debounce
  ///       .do { scheduler.advance(by: 0.25) },
  ///       // Advance the scheduler to the debounce
  ///       .do { scheduler.advance(by: 0.25) },
  ///       // Assert that the expected response is received
  ///       .receive(.response(["Composable Architecture"])) {
  ///         // Assert that state updates accordingly
  ///         $0.results = ["Composable Architecture"]
  ///       }
  ///     )
  public final class TestStore<State, LocalState, Action: Equatable, LocalAction, Environment> {
    private var environment: Environment
    private let fromLocalAction: (LocalAction) -> Action
    private let reducer: Reducer<State, Action, Environment>
    private var state: State
    private let toLocalState: (State) -> LocalState

    private init(
      initialState: State,
      reducer: Reducer<State, Action, Environment>,
      environment: Environment,
      state toLocalState: @escaping (State) -> LocalState,
      action fromLocalAction: @escaping (LocalAction) -> Action
    ) {
      self.state = initialState
      self.reducer = reducer
      self.environment = environment
      self.toLocalState = toLocalState
      self.fromLocalAction = fromLocalAction
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
        initialState: initialState,
        reducer: reducer,
        environment: environment,
        state: { $0 },
        action: { $0 }
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
      var receivedActions: [Action] = []

      var cancellables: [AnyCancellable] = []

      func runReducer(action: Action) {
        let effect = self.reducer.run(&self.state, action, self.environment)
        var isComplete = false
        var cancellable: AnyCancellable?
        cancellable = effect.sink(
          receiveCompletion: { _ in
            isComplete = true
            guard let cancellable = cancellable else { return }
            cancellables.removeAll(where: { $0 == cancellable })
          },
          receiveValue: {
            receivedActions.append($0)
          }
        )
        if !isComplete, let cancellable = cancellable {
          cancellables.append(cancellable)
        }
      }

      for step in steps {
        var expectedState = toLocalState(state)

        switch step.type {
        case let .send(action, update):
          if !receivedActions.isEmpty {
            _XCTFail(
              """
              Must handle \(receivedActions.count) received \
              action\(receivedActions.count == 1 ? "" : "s") before sending an action: …

              Unhandled actions: \(debugOutput(receivedActions))
              """,
              file: step.file, line: step.line
            )
          }
          runReducer(action: self.fromLocalAction(action))
          update(&expectedState)

        case let .receive(expectedAction, update):
          guard !receivedActions.isEmpty else {
            _XCTFail(
              """
              Expected to receive an action, but received none.
              """,
              file: step.file,
              line: step.line
            )
            break
          }
          let receivedAction = receivedActions.removeFirst()
          if expectedAction != receivedAction {
            let diff =
              debugDiff(expectedAction, receivedAction)
              .map { ": …\n\n\($0.indent(by: 4))\n\n(Expected: −, Actual: +)" }
              ?? ""
            _XCTFail(
              """
              Received unexpected action\(diff)
              """,
              file: step.file,
              line: step.line
            )
          }
          runReducer(action: receivedAction)
          update(&expectedState)

        case let .environment(work):
          if !receivedActions.isEmpty {
            _XCTFail(
              """
              Must handle \(receivedActions.count) received \
              action\(receivedActions.count == 1 ? "" : "s") before performing this work: …

              Unhandled actions: \(debugOutput(receivedActions))
              """,
              file: step.file, line: step.line
            )
          }

          work(&self.environment)
        }

        let actualState = self.toLocalState(self.state)
        if expectedState != actualState {
          let diff =
            debugDiff(expectedState, actualState)
            .map { ": …\n\n\($0.indent(by: 4))\n\n(Expected: −, Actual: +)" }
            ?? ""
          _XCTFail(
            """
            State change does not match expectation\(diff)
            """,
            file: step.file,
            line: step.line
          )
        }
      }

      if !receivedActions.isEmpty {
        _XCTFail(
          """
          Received \(receivedActions.count) unexpected \
          action\(receivedActions.count == 1 ? "" : "s"): …

          Unhandled actions: \(debugOutput(receivedActions))
          """,
          file: file,
          line: line
        )
      }
      if !cancellables.isEmpty {
        _XCTFail(
          """
          Some effects are still running. All effects must complete by the end of the assertion.

          This can happen for a few reasons:

          • If you are using a scheduler in your effect, then make sure that you wait enough time \
          for the effect to finish. If you are using a test scheduler, then make sure you advance \
          the scheduler so that the effects complete.

          • If you are using long-living effects (for example timers, notifications, etc.), then \
          ensure those effects are completed by returning an `Effect.cancel` effect from a \
          particular action in your reducer, and sending that action in the test.
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
        initialState: self.state,
        reducer: self.reducer,
        environment: self.environment,
        state: { toLocalState(self.toLocalState($0)) },
        action: { self.fromLocalAction(fromLocalAction($0)) }
      )
    }

    /// Scopes a store to assert against more local state.
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
        _ update: @escaping (inout LocalState) -> Void = { _ in }
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
        _ update: @escaping (inout LocalState) -> Void = { _ in }
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
        _ update: @escaping (inout Environment) -> Void
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
        _ work: @escaping () -> Void
      ) -> Step {
        self.environment(file: file, line: line) { _ in work() }
      }

      fileprivate enum StepType {
        case send(LocalAction, (inout LocalState) -> Void)
        case receive(Action, (inout LocalState) -> Void)
        case environment((inout Environment) -> Void)
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
