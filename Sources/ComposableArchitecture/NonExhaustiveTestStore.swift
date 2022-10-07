#if DEBUG
  import Combine
  import Foundation
  import XCTestDynamicOverlay

  final class NonExhaustiveTestStore<State, LocalState, Action: Equatable, LocalAction, Environment> {
    typealias TCATestStoreType = TestStore<State, LocalState, Action, LocalAction, Environment>
    var environment: Environment
    public var timeout: UInt64 = NSEC_PER_SEC

    private let effectDidSubscribe = AsyncStream<Void>.streamWithContinuation()
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
        reducer: Reducer<State, TCATestStoreType.TestAction, Void> { [weak self] state, action, _ in
          guard let self = self else {
            XCTFail("Received an action after store was \(Self.self) was already gone.")
            return .none
          }
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

          switch effects.operation {
          case .none:
            self.effectDidSubscribe.continuation.yield()
            return .none

          case .publisher, .run:
            let effect = TCATestStoreType.LongLivingEffect(file: action.file, line: action.line)
            return effects
              .handleEvents(
                receiveSubscription: { [effectDidSubscribe = self.effectDidSubscribe, weak self] _ in
                  self?.longLivingEffects.insert(effect)
                  Task {
                    await Task.megaYield()
                    effectDidSubscribe.continuation.yield()
                  }
                },
                receiveCompletion: { [weak self] _ in self?.longLivingEffects.remove(effect) },
                receiveCancel: { [weak self] in self?.longLivingEffects.remove(effect) }
              )
              .map { .init(origin: .receive($0), file: action.file, line: action.line) }
              .eraseToEffect()
          }
        },
        environment: (),
        instrumentation: .noop
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
    @MainActor
    @discardableResult
    internal func send(
      _ action: LocalAction,
      _ update: ((inout LocalState) throws -> Void)? = nil,
      file: StaticString = #file,
      line: UInt = #line
    ) async -> ViewStoreTask {
      let task =  { send(action, update, file: file, line: line) }()
      await Task.megaYield(count: 20)
      return task
    }

    @discardableResult
    @available(iOS, deprecated: 9999.0, message: "Call the async-friendly 'send' instead.")
    @available(macOS, deprecated: 9999.0, message: "Call the async-friendly 'send' instead.")
    @available(tvOS, deprecated: 9999.0, message: "Call the async-friendly 'send' instead.")
    @available(watchOS, deprecated: 9999.0, message: "Call the async-friendly 'send' instead.")
    internal func send(
      _ action: LocalAction,
      _ update: ((inout LocalState) throws -> Void)? = nil,
      file: StaticString = #file,
      line: UInt = #line
    ) -> ViewStoreTask {
      receivedActions.removeAll() // When developer explicitly sends an action, reset all recorded ones so we can compare from this point in time

      let task = verifyUpdateBlockMatchesState(
          actionToSend: action,
          file: file,
          line: line,
          update
      )

      if "\(self.file)" == "\(file)" {
        self.line = line
      }
      return task!
    }

    /// Asserts an action was received from an effect and asserts how the state changes.
    ///
    /// - Parameters:
    ///   - expectedAction: An action expected from an effect.
    ///   - timeout: The amount of time to wait for the expected action.
    ///   - updateExpectingResult: A closure that asserts state changed by sending the action to the
    ///     store. The mutable state sent to this closure must be modified to match the state of the
    ///     store after processing the given action. Do not provide a closure if no change is
    ///     expected.
    @MainActor
    func receive(
      _ expectedAction: Action,
      timeout nanoseconds: UInt64? = nil,
      _ updateExpectingResult: ((inout LocalState) throws -> Void)? = nil,
      file: StaticString = #file,
      line: UInt = #line
    ) async {
      let nanoseconds = nanoseconds ?? self.timeout

      guard !self.longLivingEffects.isEmpty
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
          if self.longLivingEffects.isEmpty {
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

    internal func receive(
      _ action: Action,
      _ update: ((inout LocalState) throws -> Void)? = nil,
      file: StaticString = #file,
      line: UInt = #line
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
        
      _ = verifyUpdateBlockMatchesState(
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
        _ update: ((inout LocalState) throws -> Void)? = nil
    ) -> ViewStoreTask? {
        let viewStore = ViewStore(
          self.store.scope(
            state: self.toLocalState,
            action: { .init(origin: .send($0), file: file, line: line) }
          )
        )
        var task: ViewStoreTask?
        if let action = actionToSend {
            task = viewStore.send(action)
        }

        // We are only asserting that update block doesn't cause state change that would NOT equal actual state change, thus ignoring any additional changes that actually happen
        let stateAfterReducerApplication = viewStore.state
        var stateAfterApplyingUpdate = stateAfterReducerApplication

        do {
          if let update = update {
            try update(&stateAfterApplyingUpdate)
          }
          try TCATestStoreType.expectedStateShouldMatch(
            expected: &stateAfterApplyingUpdate,
            actual: stateAfterReducerApplication,
            file: file,
            line: line
          )
        } catch {
          XCTFail("Threw error: \(error)", file: file, line: line)
        }
        return task
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
    func finish(
      timeout nanoseconds: UInt64? = nil,
      file: StaticString = #file,
      line: UInt = #line
    ) async {
      let nanoseconds = nanoseconds ?? self.timeout
      let start = DispatchTime.now().uptimeNanoseconds
      await Task.megaYield()
      while !self.longLivingEffects.isEmpty {
        guard start.distance(to: DispatchTime.now().uptimeNanoseconds) < nanoseconds
        else { return }
        await Task.megaYield()
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
