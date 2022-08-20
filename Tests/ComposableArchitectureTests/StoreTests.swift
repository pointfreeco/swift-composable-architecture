import Combine
import XCTest

@testable import ComposableArchitecture

@MainActor
final class StoreTests: XCTestCase {
  var cancellables: Set<AnyCancellable> = []

  func testCancellableIsRemovedOnImmediatelyCompletingEffect() {
    let store = Store(initialState: (), reducer: EmptyReducer<Void, Void>())

    XCTAssertNoDifference(store.effectCancellables.count, 0)

    _ = store.send(())

    XCTAssertNoDifference(store.effectCancellables.count, 0)
  }

  func testCancellableIsRemovedWhenEffectCompletes() {
    let mainQueue = DispatchQueue.test
    let effect = Effect<Void, Never>(value: ())
      .delay(for: 1, scheduler: mainQueue)
      .eraseToEffect()

    enum Action { case start, end }

    let reducer = Reduce<Void, Action> { _, action in
      switch action {
      case .start:
        return effect.map { .end }
      case .end:
        return .none
      }
    }
    let store = Store(initialState: (), reducer: reducer)

    XCTAssertNoDifference(store.effectCancellables.count, 0)

    _ = store.send(.start)

    XCTAssertNoDifference(store.effectCancellables.count, 1)

    mainQueue.advance(by: 2)

    XCTAssertNoDifference(store.effectCancellables.count, 0)
  }

  func testScopedStoreReceivesUpdatesFromParent() {
    let counterReducer = Reduce<Int, Void> { state, _ in
      state += 1
      return .none
    }

    let parentStore = Store(initialState: 0, reducer: counterReducer)
    let parentViewStore = ViewStore(parentStore)
    let childStore = parentStore.scope(state: String.init)

    var values: [String] = []
    childStore.state
      .sink(receiveValue: { values.append($0) })
      .store(in: &self.cancellables)

    XCTAssertNoDifference(values, ["0"])

    parentViewStore.send(())

    XCTAssertNoDifference(values, ["0", "1"])
  }

  func testParentStoreReceivesUpdatesFromChild() {
    let counterReducer = Reduce<Int, Void> { state, _ in
      state += 1
      return .none
    }

    let parentStore = Store(initialState: 0, reducer: counterReducer)
    let childStore = parentStore.scope(state: String.init)
    let childViewStore = ViewStore(childStore)

    var values: [Int] = []
    parentStore.state
      .sink(receiveValue: { values.append($0) })
      .store(in: &self.cancellables)

    XCTAssertNoDifference(values, [0])

    childViewStore.send(())

    XCTAssertNoDifference(values, [0, 1])
  }

  func testScopeCallCount() {
    let counterReducer = Reduce<Int, Void> { state, _ in
      state += 1
      return .none
    }

    var numCalls1 = 0
    _ = Store(initialState: 0, reducer: counterReducer)
      .scope(state: { (count: Int) -> Int in
        numCalls1 += 1
        return count
      })

    XCTAssertNoDifference(numCalls1, 1)
  }

  func testScopeCallCount2() {
    let counterReducer = Reduce<Int, Void> { state, _ in
      state += 1
      return .none
    }

    var numCalls1 = 0
    var numCalls2 = 0
    var numCalls3 = 0

    let store1 = Store(initialState: 0, reducer: counterReducer)
    let store2 =
      store1
      .scope(state: { (count: Int) -> Int in
        numCalls1 += 1
        return count
      })
    let store3 =
      store2
      .scope(state: { (count: Int) -> Int in
        numCalls2 += 1
        return count
      })
    let store4 =
      store3
      .scope(state: { (count: Int) -> Int in
        numCalls3 += 1
        return count
      })

    _ = ViewStore(store1)
    _ = ViewStore(store2)
    _ = ViewStore(store3)
    let viewStore4 = ViewStore(store4)

    XCTAssertNoDifference(numCalls1, 1)
    XCTAssertNoDifference(numCalls2, 1)
    XCTAssertNoDifference(numCalls3, 1)

    viewStore4.send(())

    XCTAssertNoDifference(numCalls1, 2)
    XCTAssertNoDifference(numCalls2, 2)
    XCTAssertNoDifference(numCalls3, 2)

    viewStore4.send(())

    XCTAssertNoDifference(numCalls1, 3)
    XCTAssertNoDifference(numCalls2, 3)
    XCTAssertNoDifference(numCalls3, 3)

    viewStore4.send(())

    XCTAssertNoDifference(numCalls1, 4)
    XCTAssertNoDifference(numCalls2, 4)
    XCTAssertNoDifference(numCalls3, 4)

    viewStore4.send(())

    XCTAssertNoDifference(numCalls1, 5)
    XCTAssertNoDifference(numCalls2, 5)
    XCTAssertNoDifference(numCalls3, 5)
  }

  func testSynchronousEffectsSentAfterSinking() {
    enum Action {
      case tap
      case next1
      case next2
      case end
    }
    var values: [Int] = []
    let counterReducer = Reduce<Void, Action> { state, action in
      switch action {
      case .tap:
        return .merge(
          Effect(value: .next1),
          Effect(value: .next2),
          .fireAndForget { values.append(1) }
        )
      case .next1:
        return .merge(
          Effect(value: .end),
          .fireAndForget { values.append(2) }
        )
      case .next2:
        return .fireAndForget { values.append(3) }
      case .end:
        return .fireAndForget { values.append(4) }
      }
    }

    let store = Store(initialState: (), reducer: counterReducer)

    _ = store.send(.tap)

    XCTAssertNoDifference(values, [1, 2, 3, 4])
  }

  func testLotsOfSynchronousActions() {
    enum Action { case incr, noop }
    let reducer = Reduce<Int, Action> { state, action in
      switch action {
      case .incr:
        state += 1
        return state >= 100_000 ? Effect(value: .noop) : Effect(value: .incr)
      case .noop:
        return .none
      }
    }

    let store = Store(initialState: 0, reducer: reducer)
    _ = store.send(.incr)
    XCTAssertNoDifference(ViewStore(store).state, 100_000)
  }

  func testIfLetAfterScope() {
    struct AppState {
      var count: Int?
    }

    let appReducer = Reduce<AppState, Int?> { state, action in
      state.count = action
      return .none
    }

    let parentStore = Store(initialState: AppState(), reducer: appReducer)

    // NB: This test needs to hold a strong reference to the emitted stores
    var outputs: [Int?] = []
    var stores: [Any] = []

    parentStore
      .scope(state: { $0.count })
      .ifLet(
        then: { store in
          stores.append(store)
          outputs.append(store.state.value)
        },
        else: {
          outputs.append(nil)
        }
      )
      .store(in: &self.cancellables)

    XCTAssertNoDifference(outputs, [nil])

    _ = parentStore.send(1)
    XCTAssertNoDifference(outputs, [nil, 1])

    _ = parentStore.send(nil)
    XCTAssertNoDifference(outputs, [nil, 1, nil])

    _ = parentStore.send(1)
    XCTAssertNoDifference(outputs, [nil, 1, nil, 1])

    _ = parentStore.send(nil)
    XCTAssertNoDifference(outputs, [nil, 1, nil, 1, nil])

    _ = parentStore.send(1)
    XCTAssertNoDifference(outputs, [nil, 1, nil, 1, nil, 1])

    _ = parentStore.send(nil)
    XCTAssertNoDifference(outputs, [nil, 1, nil, 1, nil, 1, nil])
  }

  func testIfLetTwo() {
    let parentStore = Store(
      initialState: 0,
      reducer: Reduce<Int?, Bool> { state, action in
        if action {
          state? += 1
          return .none
        } else {
          return Just(true).receive(on: DispatchQueue.main).eraseToEffect()
        }
      }
    )

    parentStore
      .ifLet(then: { childStore in
        let vs = ViewStore(childStore)

        vs
          .publisher
          .sink { _ in }
          .store(in: &self.cancellables)

        vs.send(false)
        _ = XCTWaiter.wait(for: [.init()], timeout: 0.1)
        vs.send(false)
        _ = XCTWaiter.wait(for: [.init()], timeout: 0.1)
        vs.send(false)
        _ = XCTWaiter.wait(for: [.init()], timeout: 0.1)
        XCTAssertNoDifference(vs.state, 3)
      })
      .store(in: &self.cancellables)
  }

  func testActionQueuing() async {
    let subject = PassthroughSubject<Void, Never>()

    enum Action: Equatable {
      case incrementTapped
      case `init`
      case doIncrement
    }

    let store = TestStore(
      initialState: 0,
      reducer: Reduce<Int, Action> { state, action in
        switch action {
        case .incrementTapped:
          subject.send()
          return .none

        case .`init`:
          return subject.map { .doIncrement }.eraseToEffect()

        case .doIncrement:
          state += 1
          return .none
        }
      }
    )

    await store.send(.`init`)
    await store.send(.incrementTapped)
    await store.receive(.doIncrement) {
      $0 = 1
    }
    await store.send(.incrementTapped)
    await store.receive(.doIncrement) {
      $0 = 2
    }
    subject.send(completion: .finished)
  }

  func testCoalesceSynchronousActions() {
    let store = Store(
      initialState: 0,
      reducer: Reduce<Int, Int> { state, action in
        switch action {
        case 0:
          return .merge(
            Effect(value: 1),
            Effect(value: 2),
            Effect(value: 3)
          )
        default:
          state = action
          return .none
        }
      }
    )

    var emissions: [Int] = []
    let viewStore = ViewStore(store)
    viewStore.publisher
      .sink { emissions.append($0) }
      .store(in: &self.cancellables)

    XCTAssertNoDifference(emissions, [0])

    viewStore.send(0)

    XCTAssertNoDifference(emissions, [0, 3])
  }

  func testBufferedActionProcessing() {
    struct ChildState: Equatable {
      var count: Int?
    }

    struct ParentState: Equatable {
      var count: Int?
      var child: ChildState?
    }

    enum ParentAction: Equatable {
      case button
      case child(Int?)
    }

    var handledActions: [ParentAction] = []
    let parentReducer = Reduce<ParentState, ParentAction> { state, action in
      handledActions.append(action)

      switch action {
      case .button:
        state.child = .init(count: nil)
        return .none

      case .child(let childCount):
        state.count = childCount
        return .none
      }
    }
    .ifLet(\.child, action: /ParentAction.child) {
      Reduce { state, action in
        state.count = action
        return .none
      }
    }

    let parentStore = Store(
      initialState: ParentState(),
      reducer: parentReducer
    )

    parentStore
      .scope(
        state: \.child,
        action: ParentAction.child
      )
      .ifLet { childStore in
        ViewStore(childStore).send(2)
      }
      .store(in: &cancellables)

    XCTAssertNoDifference(handledActions, [])

    _ = parentStore.send(.button)
    XCTAssertNoDifference(
      handledActions,
      [
        .button,
        .child(2),
      ])
  }

  func testCascadingTaskCancellation() async {
    enum Action { case task, response, response1, response2 }
    let reducer = Reduce<Int, Action> { state, action in
      switch action {
      case .task:
        return .task { .response }
      case .response:
        return .merge(
          Empty(completeImmediately: false).eraseToEffect(),
          .task { .response1 }
        )
      case .response1:
        return .merge(
          Empty(completeImmediately: false).eraseToEffect(),
          .task { .response2 }
        )
      case .response2:
        return Empty(completeImmediately: false).eraseToEffect()
      }
    }

    let store = TestStore(
      initialState: 0,
      reducer: reducer
    )

    let task = await store.send(.task)
    await store.receive(.response)
    await store.receive(.response1)
    await store.receive(.response2)
    await task.cancel()
  }

  func testTaskCancellationEmpty() async {
    enum Action { case task }

    let store = TestStore(
      initialState: 0,
      reducer: Reduce<Int, Action> { state, action in
        switch action {
        case .task:
          return .fireAndForget { try await Task.never() }
        }
      }
    )

    await store.send(.task).cancel()
  }

  func testScopeCancellation() async throws {
    let neverEndingTask = Task<Void, Error> { try await Task.never() }

    let store = Store(
      initialState: (),
      reducer: Reduce<Void, Void> { _, _ in
        .fireAndForget {
          try await neverEndingTask.value
        }
      }
    )
    let scopedStore = store.scope(state: { $0 })

    let sendTask = scopedStore.send(())
    await Task.yield()
    neverEndingTask.cancel()
    try await XCTUnwrap(sendTask).value
    XCTAssertEqual(store.effectCancellables.count, 0)
    XCTAssertEqual(scopedStore.effectCancellables.count, 0)
  }
}
