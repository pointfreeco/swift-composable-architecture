#if DEBUG
  import Combine
  import Foundation
  import XCTestDynamicOverlay

  final class NonExhaustiveTestStore<State, LocalState, Action: Equatable, LocalAction, Environment> {
    typealias TCATestStoreType = TestStore<State, LocalState, Action, LocalAction, Environment>
    var environment: Environment

    private let file: StaticString
    private let fromLocalAction: (LocalAction) -> Action
    private var line: UInt
    private var longLivingEffects: Set<TCATestStoreType.LongLivingEffect> = []
    private var receivedActions: [(action: Action, state: State)] = []
    private let reducer: Reducer<State, Action, Environment>
    private var store: Store<State, TCATestStoreType.TestAction>!
    private let toLocalState: (State) -> LocalState
    private(set) var snapshotState: State

    init(
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
      self.snapshotState = initialState

      self.store = Store(
        initialState: initialState,
        reducer: Reducer<State, TCATestStoreType.TestAction, Void> { [unowned self] state, action, _ in
          let effects: Effect<Action, Never>
          switch action.origin {
          case let .send(localAction):
            effects = self.reducer.run(&state, self.fromLocalAction(localAction), self.environment)
            self.snapshotState = state

          case let .receive(action):
            effects = self.reducer.run(&state, action, self.environment)
            self.snapshotState = state
            self.receivedActions.append((action, state))
          }

          let effect = TCATestStoreType.LongLivingEffect(file: action.file, line: action.line)
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

    internal func assertEffectCompleted() {
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
  }

  extension NonExhaustiveTestStore where State == LocalState, Action == LocalAction {
    internal convenience init(
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

  extension NonExhaustiveTestStore where LocalState: Equatable {
    internal func send(
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
      
    internal func receive(
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
          try TCATestStoreType.expectedStateShouldMatch(
            expected: &stateAfterApplyingUpdate,
            actual: stateAfterReducerApplication,
            file: file,
            line: line
          )
        } catch {
          XCTFail("Threw error: \(error)", file: file, line: line)
        }
    }
  }

  extension NonExhaustiveTestStore {
    internal func scope<S, A>(
      state toLocalState: @escaping (LocalState) -> S,
      action fromLocalAction: @escaping (A) -> LocalAction
    ) -> NonExhaustiveTestStore<State, S, Action, A, Environment> {
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

    internal func scope<S>(
      state toLocalState: @escaping (LocalState) -> S
    ) -> NonExhaustiveTestStore<State, S, Action, LocalAction, Environment> {
      self.scope(state: toLocalState, action: { $0 })
    }
  }
#endif
