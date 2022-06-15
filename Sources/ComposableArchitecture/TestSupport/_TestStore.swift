import XCTestDynamicOverlay

private class TestReducer<Upstream>: ReducerProtocol where Upstream: ReducerProtocol {
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
    let reducer = self.upstream.dependency(\.isTesting, true)

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
        receiveSubscription: { [weak self] _ in
          self?.inFlightEffects.insert(effect)
        },
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

// TODO: don't erase reducer in test store
public final class _TestStore<Reducer: ReducerProtocol> {
  private let file: StaticString
  private var line: UInt
  private let testReducer: TestReducer<Reducer>
  private var store: StoreOf<TestReducer<Reducer>>!

  public init(
    initialState: Reducer.State,
    reducer: Reducer,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    self.file = file
    self.line = line

    self.testReducer = TestReducer(reducer, initialState: initialState)
    self.store = Store(initialState: initialState, reducer: self.testReducer)
  }

  deinit {
    self.completed()
    DependencyValues.current.storage = [:]
  }

  public var state: Reducer.State {
    self.store.state.value
  }

  public var reducer: Reducer {
    self.testReducer.upstream
  }

  private func completed() {
    if !self.testReducer.receivedActions.isEmpty {
      var actions = ""
      customDump(self.testReducer.receivedActions.map(\.action), to: &actions)
      XCTFail(
        """
        The store received \(self.testReducer.receivedActions.count) unexpected \
        action\(self.testReducer.receivedActions.count == 1 ? "" : "s") after this one: …

        Unhandled actions: \(actions)
        """,
        file: self.file, line: self.line
      )
    }
    for effect in self.testReducer.inFlightEffects {
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

extension _TestStore where Reducer.State: Equatable {
  @discardableResult
  public func send(
    _ action: Reducer.Action,
    _ updateExpectingResult: ((inout Reducer.State) throws -> Void)? = nil,
    file: StaticString = #file,
    line: UInt = #line
  ) -> TestTask {
    if !self.testReducer.receivedActions.isEmpty {
      var actions = ""
      customDump(self.testReducer.receivedActions.map(\.action), to: &actions)
      XCTFail(
        """
        Must handle \(self.testReducer.receivedActions.count) received \
        action\(self.testReducer.receivedActions.count == 1 ? "" : "s") before sending an action: …

        Unhandled actions: \(actions)
        """,
        file: file, line: line
      )
    }
    var expectedState = self.testReducer.state
    let previousState = self.testReducer.state
    let task = self.store.send(.init(origin: .send(action), file: file, line: line))
    do {
      let currentState = self.testReducer.state
      self.testReducer.state = previousState
      defer { self.testReducer.state = currentState }

      try self.expectedStateShouldMatch(
        expected: &expectedState,
        actual: currentState,
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

  private func expectedStateShouldMatch(
    expected: inout Reducer.State,
    actual: Reducer.State,
    modify: ((inout Reducer.State) throws -> Void)? = nil,
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

extension _TestStore where Reducer.State: Equatable, Reducer.Action: Equatable {
  public func receive(
    _ expectedAction: Reducer.Action,
    _ updateExpectingResult: ((inout Reducer.State) throws -> Void)? = nil,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    guard !self.testReducer.receivedActions.isEmpty else {
      XCTFail(
        """
        Expected to receive an action, but received none.
        """,
        file: file, line: line
      )
      return
    }
    let (receivedAction, state) = self.testReducer.receivedActions.removeFirst()
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
    var expectedState = self.testReducer.state
    do {
      try expectedStateShouldMatch(
        expected: &expectedState,
        actual: state,
        modify: updateExpectingResult,
        file: file,
        line: line
      )
    } catch {
      XCTFail("Threw error: \(error)", file: file, line: line)
    }
    self.testReducer.state = state
    if "\(self.file)" == "\(file)" {
      self.line = line
    }
  }

  public func receive(
    _ expectedAction: Reducer.Action,
    timeout nanoseconds: UInt64 = NSEC_PER_SEC,  // TODO: Better default? Remove default?
    file: StaticString = #file,
    line: UInt = #line,
    _ update: ((inout Reducer.State) throws -> Void)? = nil
  ) async {
    await withTaskGroup(of: Void.self) { group in
      _ = group.addTaskUnlessCancelled { @MainActor in
        while !Task.isCancelled {
          guard self.testReducer.receivedActions.isEmpty
          else { break }
          await Task.yield()
        }
        guard !Task.isCancelled
        else { return }

        { self.receive(expectedAction, update, file: file, line: line) }()
      }

      _ = group.addTaskUnlessCancelled { @MainActor in
        await Task(priority: .low) { try? await Task.sleep(nanoseconds: nanoseconds) }
          .cancellableValue
        guard !Task.isCancelled
        else { return }

        let suggestion: String
        if self.testReducer.inFlightEffects.isEmpty {
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
