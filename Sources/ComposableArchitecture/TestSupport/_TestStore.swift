//#if DEBUG
import Combine
import CustomDump
import Foundation
import XCTestDynamicOverlay

private class TestReducer<Upstream>: _Reducer where Upstream: _Reducer {
  let upstream: Upstream
  var snapshotState: Upstream.State
  var longLivingEffects: Set<LongLivingEffect> = []
  var receivedActions: [(action: Upstream.Action, state: Upstream.State)] = []

  init(
    _ upstream: Upstream,
    initialState: Upstream.State
  ) {
    self.upstream = upstream
    self.snapshotState = initialState
  }

  func reduce(into state: inout Upstream.State, action: TestAction) -> Effect<TestAction, Never> {
    let effects: Effect<Upstream.Action, Never>
    switch action.origin {
    case let .send(action):
      effects = self.upstream.reduce(into: &state, action: action)
      self.snapshotState = state

    case let .receive(action):
      effects = self.upstream.reduce(into: &state, action: action)
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

public final class _TestStore<Reducer> where Reducer: _Reducer {
  private let file: StaticString
  private var line: UInt
  private let reducer: TestReducer<Reducer>
  private var store: Store<Reducer.State, TestReducer<Reducer>.TestAction>!

  public init(
    initialState: Reducer.State,
    reducer: Reducer,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    self.file = file
    self.line = line
    self.reducer = TestReducer(reducer, initialState: initialState)
    self.store = Store(initialState: initialState, reducer: self.reducer)
  }

  deinit {
    self.completed()
  }

  private func completed() {
    if !self.reducer.receivedActions.isEmpty {
      var actions = ""
      customDump(self.reducer.receivedActions.map(\.action), to: &actions)
      XCTFail(
        """
        The store received \(self.reducer.receivedActions.count) unexpected \
        action\(self.reducer.receivedActions.count == 1 ? "" : "s") after this one: …

        Unhandled actions: \(actions)
        """,
        file: self.file, line: self.line
      )
    }
    for effect in self.reducer.longLivingEffects {
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
  public func send(
    _ action: Reducer.Action,
    file: StaticString = #file,
    line: UInt = #line,
    _ update: @escaping (inout Reducer.State) throws -> Void = { _ in }
  ) {
    if !self.reducer.receivedActions.isEmpty {
      var actions = ""
      customDump(self.reducer.receivedActions.map(\.action), to: &actions)
      XCTFail(
        """
        Must handle \(self.reducer.receivedActions.count) received \
        action\(self.reducer.receivedActions.count == 1 ? "" : "s") before sending an action: …

        Unhandled actions: \(actions)
        """,
        file: file, line: line
      )
    }
    var expectedState = self.reducer.snapshotState
    ViewStore(
      self.store.scope(
        state: { _ in },
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
      actual: self.reducer.snapshotState,
      file: file,
      line: line
    )
    if "\(self.file)" == "\(file)" {
      self.line = line
    }
  }

  private func expectedStateShouldMatch(
    expected: Reducer.State,
    actual: Reducer.State,
    file: StaticString,
    line: UInt
  ) {
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
        """,
        file: file,
        line: line
      )
    }
  }
}

extension _TestStore where Reducer.State: Equatable, Reducer.Action: Equatable {
  public func receive(
    _ expectedAction: Reducer.Action,
    file: StaticString = #file,
    line: UInt = #line,
    _ update: @escaping (inout Reducer.State) throws -> Void = { _ in }
  ) {
    guard !self.reducer.receivedActions.isEmpty else {
      XCTFail(
        """
        Expected to receive an action, but received none.
        """,
        file: file, line: line
      )
      return
    }
    let (receivedAction, state) = self.reducer.receivedActions.removeFirst()
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
    var expectedState = self.reducer.snapshotState
    do {
      try update(&expectedState)
    } catch {
      XCTFail("Threw error: \(error)", file: file, line: line)
    }
    self.expectedStateShouldMatch(
      expected: expectedState,
      actual: state,
      file: file,
      line: line
    )
    self.reducer.snapshotState = state
    if "\(self.file)" == "\(file)" {
      self.line = line
    }
  }
}
//#endif
