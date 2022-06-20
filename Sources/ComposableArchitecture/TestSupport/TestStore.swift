#if DEBUG
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
  /// struct CounterReducer: ReducerProtocol {
  ///   struct State {
  ///     var count = 0
  ///   }
  ///   enum Action: Equatable {
  ///     case decrementButtonTapped
  ///     case incrementButtonTapped
  ///   }
  ///   func reduce(into state: inout State, action: Action) -> Effect<Action> {
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
  /// class CounterTests: XCTestCase {
  ///   func testCounter() {
  ///     let store = TestStore(
  ///       initialState: .init(count: 0),      // Given a counter state of 0
  ///       reducer: CounterReducer()
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
  /// struct SearchReducer: ReducerProtocol {
  ///   struct State: Equatable {
  ///     var query = ""
  ///     var results: [String] = []
  ///   }
  ///   enum Action: Equatable {
  ///     case queryChanged(String)
  ///     case response([String])
  ///   }
  ///   @Dependency(\.mainQueue) var mainQueue
  ///   let request: @Sendable (String) async throws -> [String]
  ///
  ///   func reduce(into state: inout State, action: Action) -> Effect<Action> {
  ///     switch action {
  ///     case let .queryChanged(query):
  ///       enum SearchId {}
  ///
  ///       state.query = query
  ///       return .run { send in
  ///         guard let results = try? await self.request(query) else { return }
  ///         send(.response(results))
  ///       }
  ///       .debounce(id: SearchId.self, for: 0.5, scheduler: environment.mainQueue)
  ///
  ///     case let .response(results):
  ///       state.results = results
  ///       return .none
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// It can be fully tested by controlling the environment's scheduler and effect:
  ///
  /// ```swift
  /// // Create a test dispatch queue to control the timing of effects
  /// let mainQueue = DispatchQueue.test
  ///
  /// let store = TestStore(
  ///   initialState: .init(),
  ///   reducer: SearchReducer(request: { ["Composable Architecture"] })
  ///     // Override the main queue dependency with a type-erased scheduler
  ///     .dependency(\.mainQueue, mainQueue.eraseToAnyScheduler()
  /// )
  ///
  /// // Change the query
  /// store.send(.searchFieldChanged("c") {
  ///   // Assert that state updates accordingly
  ///   $0.query = "c"
  /// }
  ///
  /// // Advance the scheduler by a period shorter than the debounce
  /// await scheduler.advance(by: 0.25)
  ///
  /// // Change the query again
  /// store.send(.searchFieldChanged("co") {
  ///   $0.query = "co"
  /// }
  ///
  /// // Advance the scheduler by a period shorter than the debounce
  /// await scheduler.advance(by: 0.25)
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
  public final class TestStore<Reducer: ReducerProtocol, LocalState, LocalAction, Environment> {
    /// The current environment.
    ///
    /// The environment can be modified throughout a test store's lifecycle in order to influence
    /// how it produces effects.
    public var environment: Environment {
      _read { yield self._environment.wrappedValue }
      _modify { yield &self._environment.wrappedValue }
    }

    public var reducer: Reducer {
      self._reducer.upstream
    }

    /// The current state.
    ///
    /// When read from a trailing closure assertion in ``send(_:_:file:line:)`` or
    /// ``receive(_:_:file:line:)``, it will equal the `inout` state passed to the closure.
    public var state: Reducer.State {
      self._reducer.state
    }

    private var _environment: Box<Environment>
    private let file: StaticString
    private let fromLocalAction: (LocalAction) -> Reducer.Action
    private var line: UInt
    let _reducer: TestReducer<Reducer>
    private var store: Store<Reducer.State, TestReducer<Reducer>.TestAction>!
    private let toLocalState: (Reducer.State) -> LocalState

    public init(
      initialState: Reducer.State,
      reducer: Reducer,
      file: StaticString = #file,
      line: UInt = #line
    )
    where
      Reducer.State == LocalState,
      Reducer.Action == LocalAction,
      Environment == Void // TODO: could this be DependencyValues and can tests change enviroment through it?
    {
      let reducer = TestReducer(reducer, initialState: initialState)
      self._reducer = reducer
      self.store = Store(initialState: initialState, reducer: reducer)
      self.toLocalState = { $0 }
      self.fromLocalAction = { $0 }
      self._environment = .init(wrappedValue: ())
      self.file = file
      self.line = line
    }

    /// Initializes a test store from an initial state, a reducer, and an initial environment.
    ///
    /// - Parameters:
    ///   - initialState: The state to start the test from.
    ///   - reducer: A reducer.
    ///   - environment: The environment to start the test from.
    public init(
      initialState: LocalState,
      reducer: ComposableArchitecture.Reducer<LocalState, LocalAction, Environment>,
      environment: Environment,
      file: StaticString = #file,
      line: UInt = #line
    )
    where
      Reducer == Reduce<LocalState, LocalAction>
    {
      let environment = Box(wrappedValue: environment)
      let reducer = TestReducer(
        Reduce(
          reducer.pullback(state: \.self, action: .self, environment: { $0.wrappedValue }),
          environment: environment
        ),
        initialState: initialState
      )
      self._reducer = reducer
      self.toLocalState = { $0 }
      self.fromLocalAction = { $0 }
      self.store = Store(initialState: initialState, reducer: reducer)
      self._environment = environment
      self.line = line
      self.file = file
    }

    private init(
      _environment: Box<Environment>,
      file: StaticString,
      fromLocalAction: @escaping (LocalAction) -> Reducer.Action,
      line: UInt,
      reducer: TestReducer<Reducer>,
      store: Store<Reducer.State, TestReducer<Reducer>.TestAction>,
      toLocalState: @escaping (Reducer.State) -> LocalState
    ) {
      self._environment = _environment
      self.file = file
      self.fromLocalAction = fromLocalAction
      self.line = line
      self._reducer = reducer
      self.store = store
      self.toLocalState = toLocalState
    }

    deinit {
      self.completed()
    }

    func completed() {
      if !self._reducer.receivedActions.isEmpty {
        var actions = ""
        customDump(self._reducer.receivedActions.map(\.action), to: &actions)
        XCTFail(
          """
          The store received \(self._reducer.receivedActions.count) unexpected \
          action\(self._reducer.receivedActions.count == 1 ? "" : "s") after this one: …

          Unhandled actions: \(actions)
          """,
          file: self.file, line: self.line
        )
      }
      for effect in self._reducer.inFlightEffects {
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
    @discardableResult
    public func send(
      _ action: LocalAction,
      _ updateExpectingResult: ((inout LocalState) throws -> Void)? = nil,
      file: StaticString = #file,
      line: UInt = #line
    ) -> TestTask {
      if !self._reducer.receivedActions.isEmpty {
        var actions = ""
        customDump(self._reducer.receivedActions.map(\.action), to: &actions)
        XCTFail(
          """
          Must handle \(self._reducer.receivedActions.count) received \
          action\(self._reducer.receivedActions.count == 1 ? "" : "s") before sending an action: …

          Unhandled actions: \(actions)
          """,
          file: file,
          line: line
        )
      }

      //

      var expectedState = self.toLocalState(self._reducer.state)
      let previousState = self._reducer.state

      let task = self.store
        .send(.init(origin: .send(self.fromLocalAction(action)), file: file, line: line))

      do {
        let currentState = self._reducer.state
        self._reducer.state = previousState
        defer { self._reducer.state = currentState }

        try expectedStateShouldMatch(
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

      return .init(task: task)
    }
  }

  extension TestStore where LocalState: Equatable, Reducer.Action: Equatable {
    /// Asserts an action was received from an effect and asserts when state changes.
    ///
    /// - Parameters:
    ///   - expectedAction: An action expected from an effect.
    ///   - updateExpectingResult: A closure that asserts state changed by sending the action to the
    ///     store. The mutable state sent to this closure must be modified to match the state of the
    ///     store after processing the given action. Do not provide a closure if no change is
    ///     expected.
    public func receive(
      _ expectedAction: Reducer.Action,
      _ updateExpectingResult: ((inout LocalState) throws -> Void)? = nil,
      file: StaticString = #file,
      line: UInt = #line
    ) {
      guard !self._reducer.receivedActions.isEmpty else {
        XCTFail(
          """
          Expected to receive an action, but received none.
          """,
          file: file, line: line
        )
        return
      }
      let (receivedAction, state) = self._reducer.receivedActions.removeFirst()
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
          file: file,
          line: line
        )
      }
      var expectedState = self.toLocalState(self._reducer.state)
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
      self._reducer.state = state
      if "\(self.file)" == "\(file)" {
        self.line = line
      }
    }

    /// Asserts an action was received from an effect and asserts when state changes.
    ///
    /// - Parameters:
    ///   - expectedAction: An action expected from an effect.
    ///   - updateExpectingResult: A closure that asserts state changed by sending the action to the
    ///     store. The mutable state sent to this closure must be modified to match the state of the
    ///     store after processing the given action. Do not provide a closure if no change is
    ///     expected.
    public func receive(
      _ expectedAction: Reducer.Action,
      timeout nanoseconds: UInt64 = NSEC_PER_SEC,  // TODO: Better default? Remove default?
      _ updateExpectingResult: ((inout LocalState) throws -> Void)? = nil,
      file: StaticString = #file,
      line: UInt = #line
    ) async {
      await withTaskGroup(of: Void.self) { group in
        _ = group.addTaskUnlessCancelled { @MainActor in
          while !Task.isCancelled {
            guard self._reducer.receivedActions.isEmpty
            else { break }
            await Task.yield()
          }
          guard !Task.isCancelled
          else { return }

          { self.receive(expectedAction, updateExpectingResult, file: file, line: line) }()
        }

        _ = group.addTaskUnlessCancelled { @MainActor in
          await Task(priority: .low) { try? await Task.sleep(nanoseconds: nanoseconds) }
            .cancellableValue
          guard !Task.isCancelled
          else { return }

          let suggestion: String
          if self._reducer.inFlightEffects.isEmpty {
            suggestion = """
              There are no in-flight effects that could deliver this action. Could the effect you \
              expected to deliver this action have been cancelled?
              """
          } else {
            let timeoutMessage = nanoseconds > 0
              ? #"try increasing the duration of this assertion's "timeout"#
              : #"configure this assertion with an explicit "timeout"#
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
        }

        await group.next()
        group.cancelAll()
      }
    }
  }

  /// The type returned from ``TestStore/send(_:_:file:line:)`` that represents the lifecycle of the
  /// effect started from sending an action.
  ///
  /// You can use this value in tests to cancel the effect started from sending an action, or to
  /// await for the effect to finish.
  public struct TestTask {
    let task: Task<Void, Never>

    public func cancel() async {
      self.task.cancel()
      await self.task.cancellableValue
    }

    public func finish(
      timeout nanoseconds: UInt64 = NSEC_PER_SEC,  // TODO: Better default? Remove default?
      file: StaticString = #file,
      line: UInt = #line
    ) async {
      do {
        try await withThrowingTaskGroup(of: Void.self) { group in
          group.addTask { await self.task.cancellableValue }
          group.addTask {
            try await Task.sleep(nanoseconds: nanoseconds)
            throw CancellationError()
          }
          try await group.next()
          group.cancelAll()
        }
      } catch {
        XCTFail(
          """
          Expected task to finish, but it is still in-flight
          """,
          file: file,
          line: line
        )
      }
    }
  }

  class TestReducer<Upstream>: ReducerProtocol where Upstream: ReducerProtocol {
    let upstream: Upstream
    var inFlightEffects: Set<LongLivingEffect> = []
    var receivedActions: [(action: Upstream.Action, state: Upstream.State)] = []
    var state: Upstream.State

    init(
      _ upstream: Upstream,
      initialState: Upstream.State
    ) {
      self.upstream = upstream
      self.state = initialState
    }

    func reduce(into state: inout Upstream.State, action: TestAction) -> Effect<TestAction, Never> {
      let reducer = self.upstream
        .dependency(\.isTesting, true) // TODO: navigationID

      let effects: Effect<Upstream.Action, Never>
      switch action.origin {
      case let .send(action):
        effects = reducer.reduce(into: &state, action: action)
        self.state = state

      case let .receive(action):
        effects = reducer.reduce(into: &state, action: action)
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
        .map { .init(origin: .receive($0), file: action.file, line: action.line) }
        .eraseToEffect()
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
        case send(Upstream.Action)
        case receive(Upstream.Action)
      }
    }
  }

  private func expectedStateShouldMatch<State: Equatable>(
    expected: inout State,
    actual: State,
    modify: ((inout State) throws -> Void)? = nil,
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
        file: file,
        line: line
      )
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
    ) -> TestStore<Reducer, S, A, Environment> {
      .init(
        _environment: self._environment,
        file: self.file,
        fromLocalAction: { self.fromLocalAction(fromLocalAction($0)) },
        line: self.line,
        reducer: self._reducer,
        store: self.store,
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
    ) -> TestStore<Reducer, S, LocalAction, Environment> {
      self.scope(state: toLocalState, action: { $0 })
    }
  }
#endif
