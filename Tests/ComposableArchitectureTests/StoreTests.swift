import Combine
import XCTest

@testable import ComposableArchitecture

final class StoreTests: XCTestCase {
  var cancellables: Set<AnyCancellable> = []

  func testCancellableIsRemovedOnImmediatelyCompletingEffect() {
    let reducer = Reducer<Void, Void, Void> { _, _, _ in .none }
    let store = Store(initialState: (), reducer: reducer, environment: ())

    XCTAssertNoDifference(store.effectCancellables.count, 0)

    store.send(())

    XCTAssertNoDifference(store.effectCancellables.count, 0)
  }

  func testCancellableIsRemovedWhenEffectCompletes() {
    let mainQueue = DispatchQueue.test
    let effect = Effect<Void, Never>(value: ())
      .delay(for: 1, scheduler: mainQueue)
      .eraseToEffect()

    enum Action { case start, end }

    let reducer = Reducer<Void, Action, Void> { _, action, _ in
      switch action {
      case .start:
        return effect.map { .end }
      case .end:
        return .none
      }
    }
    let store = Store(initialState: (), reducer: reducer, environment: ())

    XCTAssertNoDifference(store.effectCancellables.count, 0)

    store.send(.start)

    XCTAssertNoDifference(store.effectCancellables.count, 1)

    mainQueue.advance(by: 2)

    XCTAssertNoDifference(store.effectCancellables.count, 0)
  }

  func testScopedStoreReceivesUpdatesFromParent() {
    let counterReducer = Reducer<Int, Void, Void> { state, _, _ in
      state += 1
      return .none
    }

    let parentStore = Store(initialState: 0, reducer: counterReducer, environment: ())
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
    let counterReducer = Reducer<Int, Void, Void> { state, _, _ in
      state += 1
      return .none
    }

    let parentStore = Store(initialState: 0, reducer: counterReducer, environment: ())
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
    let counterReducer = Reducer<Int, Void, Void> { state, _, _ in state += 1
      return .none
    }

    var numCalls1 = 0
    _ = Store(initialState: 0, reducer: counterReducer, environment: ())
      .scope(state: { (count: Int) -> Int in
        numCalls1 += 1
        return count
      })

    XCTAssertNoDifference(numCalls1, 1)
  }

  func testScopeCallCount2() {
    let counterReducer = Reducer<Int, Void, Void> { state, _, _ in
      state += 1
      return .none
    }

    var numCalls1 = 0
    var numCalls2 = 0
    var numCalls3 = 0

    let store1 = Store(initialState: 0, reducer: counterReducer, environment: ())
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
    let counterReducer = Reducer<Void, Action, Void> { state, action, _ in
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

    let store = Store(initialState: (), reducer: counterReducer, environment: ())

    store.send(.tap)

    XCTAssertNoDifference(values, [1, 2, 3, 4])
  }

  func testLotsOfSynchronousActions() {
    enum Action { case incr, noop }
    let reducer = Reducer<Int, Action, ()> { state, action, _ in
      switch action {
      case .incr:
        state += 1
        return state >= 100_000 ? Effect(value: .noop) : Effect(value: .incr)
      case .noop:
        return .none
      }
    }

    let store = Store(initialState: 0, reducer: reducer, environment: ())
    store.send(.incr)
    XCTAssertNoDifference(ViewStore(store).state, 100_000)
  }

  func testIfLetAfterScope() {
    struct AppState {
      var count: Int?
    }

    let appReducer = Reducer<AppState, Int?, Void> { state, action, _ in
      state.count = action
      return .none
    }

    let parentStore = Store(initialState: AppState(), reducer: appReducer, environment: ())

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

    parentStore.send(1)
    XCTAssertNoDifference(outputs, [nil, 1])

    parentStore.send(nil)
    XCTAssertNoDifference(outputs, [nil, 1, nil])

    parentStore.send(1)
    XCTAssertNoDifference(outputs, [nil, 1, nil, 1])

    parentStore.send(nil)
    XCTAssertNoDifference(outputs, [nil, 1, nil, 1, nil])

    parentStore.send(1)
    XCTAssertNoDifference(outputs, [nil, 1, nil, 1, nil, 1])

    parentStore.send(nil)
    XCTAssertNoDifference(outputs, [nil, 1, nil, 1, nil, 1, nil])
  }

  func testIfLetTwo() {
    let parentStore = Store(
      initialState: 0,
      reducer: Reducer<Int?, Bool, Void> { state, action, _ in
        if action {
          state? += 1
          return .none
        } else {
          return Just(true).receive(on: DispatchQueue.main).eraseToEffect()
        }
      },
      environment: ()
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

  func testActionQueuing() {
    let subject = PassthroughSubject<Void, Never>()

    enum Action: Equatable {
      case incrementTapped
      case `init`
      case doIncrement
    }

    let store = TestStore(
      initialState: 0,
      reducer: Reducer<Int, Action, Void> { state, action, _ in
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
      },
      environment: ()
    )

    store.send(.`init`)
    store.send(.incrementTapped)
    store.receive(.doIncrement) {
      $0 = 1
    }
    store.send(.incrementTapped)
    store.receive(.doIncrement) {
      $0 = 2
    }
    subject.send(completion: .finished)
  }

  func testCoalesceSynchronousActions() {
    let store = Store(
      initialState: 0,
      reducer: Reducer<Int, Int, Void> { state, action, _ in
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
      },
      environment: ()
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

    let childReducer = Reducer<ChildState, Int?, Void> { state, action, _ in
      state.count = action
      return .none
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
    let parentReducer = Reducer.combine([
      childReducer
        .optional()
        .pullback(
          state: \.child,
          action: /ParentAction.child,
          environment: {}
        ),
      Reducer<ParentState, ParentAction, Void> { state, action, _ in
        handledActions.append(action)

        switch action {
        case .button:
          state.child = .init(count: nil)
          return .none

        case .child(let childCount):
          state.count = childCount
          return .none
        }
      },
    ])

    let parentStore = Store(
      initialState: .init(),
      reducer: parentReducer,
      environment: ()
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

    parentStore.send(.button)
    XCTAssertNoDifference(
      handledActions,
      [
        .button,
        .child(2),
      ])
  }

  func testNonMainQueueStore() {
    var expectations: [XCTestExpectation] = []
    for i in 1...100 {
      let expectation = XCTestExpectation(description: "\(i)th iteration is complete")
      expectations.append(expectation)
      DispatchQueue.global().async {
        let viewStore = ViewStore(
          Store.unchecked(
            initialState: 0,
            reducer: Reducer<Int, Void, XCTestExpectation> { state, _, expectation in
              state += 1
              if state == 2 {
                return .fireAndForget { expectation.fulfill() }
              }
              return .none
            },
            environment: expectation
          )
        )
        viewStore.send(())
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
          viewStore.send(())
        }
      }
    }

    wait(for: expectations, timeout: 1)
  }
}
