import Combine
import CustomDump
import Foundation
import SwiftUI
import XCTestDynamicOverlay

@MainActor
public final class MainActorTestStore<State, Action, Environment> {
  public var environment: Environment
  private let reducer: Reducer<State, Action, Environment>
  private var snapshotState: State
  private var store: MainActorStore<State, TestAction>!
  private var receivedActions: [(action: Action, state: State)] = []
  private var longLivingEffects: Set<AnyHashable> = []

  private let receivedActionsStream: AsyncStream<(action: Action, state: State)>
  private var receivedActionsContinuation: AsyncStream<(action: Action, state: State)>.Continuation!

  public init(
    initialState: State,
    reducer: Reducer<State, Action, Environment>,
    environment: Environment
  ) {

    var receivedActionsContinuation: AsyncStream<(action: Action, state: State)>.Continuation!
    self.receivedActionsStream = AsyncStream { continuation in
      receivedActionsContinuation = continuation
    }
    self.receivedActionsContinuation = receivedActionsContinuation


    self.environment = environment
    self.reducer = reducer
    self.snapshotState = initialState
    self.store = .init(
      initialState: initialState,
      reducer: Reducer<State, TestAction, Void> { [unowned self] state, action, _ in
        let effects: Effect<Action, Never>

        switch action {
        case let .send(action):
          effects = self.reducer.run(&state, action, self.environment)
          self.snapshotState = state


        case let .receive(action):
          effects = self.reducer.run(&state, action, self.environment)
          self.receivedActions.append((action, state))
          self.receivedActionsContinuation.yield((action, state))
        }

        let effectId = UUID()
        return effects
          .handleEvents(
            receiveSubscription: { [weak self] _ in
              _ = self?.longLivingEffects.insert(effectId)
            },
            receiveCompletion: { [weak self] _ in
              self?.longLivingEffects.remove(effectId)
            },
            receiveCancel: { [weak self] in
              self?.longLivingEffects.remove(effectId)
            }
          )
          .map(TestAction.receive)
          .eraseToEffect()
      },
      environment: ()
    )
  }
  //
  //  public struct Task {
  //    let task: Task<Void, Never>
  //    public func cancel() async {
  //      self.task.cancel()
  //      try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)
  //    }
  //  }

  @discardableResult
  public func send(
    _ action: Action,
    _ update: @escaping (inout State) throws -> Void = { _ in }
  )
  -> Task<Void, Never>
  where State: Equatable
  {
    if !self.receivedActions.isEmpty {
      var actions = ""
      customDump(self.receivedActions.map(\.action), to: &actions)
      XCTFail(
        """
        Must handle \(self.receivedActions.count) received \
        action\(self.receivedActions.count == 1 ? "" : "s") before sending an action: …

        Unhandled actions: \(actions)
        """
      )
    }

    var expectedState = self.snapshotState

    let task = self.store.send(.send(action))

    do {
      try update(&expectedState)
    } catch {
      XCTFail("Threw error: \(error)")
    }

    self.expectedStateShouldMatch(
      expected: expectedState,
      actual: self.snapshotState
    )

    return task
  }

  public func receive(
    _ expectedAction: Action,
    _ update: @escaping (inout State) throws -> Void = { _ in }
  ) async
  where
State: Equatable,
Action: Equatable
  {
    for await received in self.receivedActionsStream {
      self.receivedActions.removeFirst()

      if expectedAction != received.action {
        XCTFail("Received unexpected action")
      }

      var expectedState = self.snapshotState
      do {
        try update(&expectedState)
      } catch {
        XCTFail("Threw error: \(error)")
      }

      self.expectedStateShouldMatch(
        expected: expectedState,
        actual: received.state
      )
      self.snapshotState = received.state

      // TODO: return?
      break
    }

    // TODO: fail?
  }

  deinit {
    if !self.receivedActions.isEmpty {
      XCTFail("The store received \(self.receivedActions.count) unexpected")
    }
    for effect in self.longLivingEffects {
      XCTFail(
        """
        An effect returned for this action is still running. It must complete before the end of \
        the test. …
        """
      )
    }
  }

  private func expectedStateShouldMatch(
    expected: State,
    actual: State
  )
  where State: Equatable
  {
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
          State change does not match expectation: …

          \(difference)
          """
      )
    }
  }

  public enum TestAction {
    case send(Action)
    case receive(Action)
  }
}



@MainActor
public final class MainActorStore<State, Action> {
  private let reducer: (inout State, Action) -> Effect<Action, Never>
  var _state: State {
    didSet {
      self.stateContinuation.yield(self._state)
    }
  }
  let stateStream: AsyncStream<State>
  private var stateContinuation: AsyncStream<State>.Continuation!
  var effectCancellables: Set<AnyCancellable> = []

  fileprivate init(
    reducer: @escaping (inout State, Action) -> Effect<Action, Never>,
    state: State
  ) {
    var stateContinuation: AsyncStream<State>.Continuation!
    self.stateStream = AsyncStream<State> { continuation in
      stateContinuation = continuation
    }
    self.stateContinuation = stateContinuation

    self.reducer = reducer
    self._state = state
  }

  public convenience init<Environment>(
    initialState: State,
    reducer: Reducer<State, Action, Environment>,
    environment: Environment
  ) {
    self.init(
      reducer: { state, action in
        reducer(&state, action, environment)
      },
      state: initialState
    )
  }

  @discardableResult
  public func send(_ action: Action) -> Task<Void, Never> {
    var _state = self._state
    let effect = self.reducer(&_state, action)
    self._state = _state

    let task = Task {
      _ = try? await Task.sleep(nanoseconds: .max)
    }
    effect
      .sink(
        receiveCompletion: { _ in
          task.cancel()
        },
        receiveValue: { action in
          self.send(action)
        }
      )
      .store(in: &self.effectCancellables)

    return task
  }

  public func send(_ action: Action) async {
    fatalError()
    //    var _state = self._state
    //    let effect = self.reducer(&_state, action)
    //    self._state = _state
    //
    //    for await effectAction in effect.values {
    //      guard !Task.isCancelled
    //      else { break }
    //
    //      await self.send(effectAction)
    //    }
  }

  public func scope<LocalState, LocalAction>(
    state toLocalState: @escaping (State) -> LocalState,
    action fromLocalAction: @escaping (LocalAction) -> Action
  ) -> MainActorStore<LocalState, LocalAction> {
    let localStore = MainActorStore<LocalState, LocalAction>(
      reducer: { localState, localAction in
        self.send(fromLocalAction(localAction))
        localState = toLocalState(self._state)
        return .none
      },
      state: toLocalState(self._state)
    )

    self.parentTask = Task { [weak localStore, weak self] in
      guard let localStore = localStore, let self = self
      else { return }
      for await newState in self.stateStream.dropFirst() {
        localStore._state = toLocalState(newState)
      }
    }

    return localStore

  }

  deinit {
    self.parentTask?.cancel()
  }

  private var parentTask: Task<Void, Never>?
}

@dynamicMemberLookup
@MainActor
public class MainActorViewStore<State, Action>: ObservableObject where Action: Sendable {
  @Published public var state: State
  public let _send: (Action) async -> Void
  private var task: Task<(), Error>!

  public init(store: MainActorStore<State, Action>) {
    self.state = store._state
    self._send = store.send
    self.task = Task {
      for await state in store.stateStream {
        try Task.checkCancellation()
        self.state = state
      }
    }
  }

  deinit {
    self.task.cancel()
  }

  public func send(_ action: Action) async {
    await self._send(action)
  }

  public func send(_ action: Action) {
    Task { await self._send(action) }
  }

  public subscript<LocalState>(dynamicMember keyPath: KeyPath<State, LocalState>) -> LocalState {
    self.state[keyPath: keyPath]
  }
}




