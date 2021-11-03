#if DEBUG
  import Combine
  import Foundation
  import XCTestDynamicOverlay

  
  public final class ARCTestStore<State, LocalState, Action: Equatable, LocalAction, Environment> {
    public var environment: Environment

    private let file: StaticString
    private let fromLocalAction: (LocalAction) -> Action
    private var line: UInt
    private var longLivingEffects: Set<LongLivingEffect> = []
    private var receivedActions: [(action: Action, state: State)] = []
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
      self.toLocalState = toLocalState

      self.store = Store(
        initialState: initialState,
        reducer: Reducer<State, TestAction, Void> { [unowned self] state, action, _ in
          let effects: Effect<Action, Never>
          switch action.origin {
          case let .send(localAction):
            effects = self.reducer.run(&state, self.fromLocalAction(localAction), self.environment)

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

    public func assertEffectCompleted() {
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

  extension ARCTestStore where State == LocalState, Action == LocalAction {
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

  extension ARCTestStore where LocalState: Equatable {
    public func send(
      _ action: LocalAction,
      file: StaticString = #file,
      line: UInt = #line,
      _ update: @escaping (inout LocalState) throws -> Void = { _ in }
    ) {
      receivedActions.removeAll() // When developer explicitly sends an action, reset all recorded ones so we can compare from this point in time
      
      verifyUpdateBlockMatchesState(
          actionToSend: action,
          file: file,
          line: line,
          update
      )
 
      if "\(self.file)" == "\(file)" {
        self.line = line
      }
    }
      
    public func receive(
      _ action: Action,
      file: StaticString = #file,
      line: UInt = #line,
      _ update: @escaping (inout LocalState) throws -> Void = { _ in }
    ) {
      guard receivedActions.contains(where: { $0.action == action }) else {
          XCTFail(
            """
            Expected to receive an action \(action), but didn't get one.
            """,
            file: file, line: line
          )
          return
      }
        
      verifyUpdateBlockMatchesState(
          actionToSend: .none,
          file: file,
          line: line,
          update
      )
      
      if "\(self.file)" == "\(file)" {
        self.line = line
      }
    }
      
    private func verifyUpdateBlockMatchesState(
        actionToSend: LocalAction?,
        file: StaticString = #file,
        line: UInt = #line,
        _ update: @escaping (inout LocalState) throws -> Void = { _ in }
    ) {
        let viewStore = ViewStore(
          self.store.scope(
            state: self.toLocalState,
            action: { .init(origin: .send($0), file: file, line: line) }
          )
        )

        if let action = actionToSend {
            viewStore.send(action)
        }

        // We are only asserting that update block doesn't cause state change that would NOT equal actual state change, thus ignoring any additional changes that actually happen
        let stateAfterReducerApplication = viewStore.state
        var stateAfterApplyingUpdate = stateAfterReducerApplication

        do {
          try update(&stateAfterApplyingUpdate)
        } catch {
          XCTFail("Threw error: \(error)", file: file, line: line)
        }

        self.expectedStateShouldMatch(
          expected: stateAfterApplyingUpdate,
          actual: stateAfterReducerApplication,
          file: file,
          line: line
        )
    }

    private func expectedStateShouldMatch(
      expected: LocalState,
      actual: LocalState,
      file: StaticString,
      line: UInt
    ) {
      if expected != actual {
        let diff =
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
          State change does not match expectation: …

          \(diff)
          """,
          file: file,
          line: line
        )
      }
    }
  }

  extension ARCTestStore {
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
    ) -> ARCTestStore<State, S, Action, A, Environment> {
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
    ) -> ARCTestStore<State, S, Action, LocalAction, Environment> {
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
#endif
