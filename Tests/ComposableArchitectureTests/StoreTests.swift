import Combine
@_spi(Internals) import ComposableArchitecture
import XCTest

@MainActor
final class StoreTests: BaseTCATestCase {
  var cancellables: Set<AnyCancellable> = []

  func testCancellableIsRemovedOnImmediatelyCompletingEffect() {
    let store = Store(initialState: (), reducer: EmptyReducer<Void, Void>())

    XCTAssertEqual(store.effectCancellables.count, 0)

    _ = store.send(())

    XCTAssertEqual(store.effectCancellables.count, 0)
  }

  func testCancellableIsRemovedWhenEffectCompletes() {
    let mainQueue = DispatchQueue.test
    let effect = EffectTask<Void>(value: ())
      .delay(for: 1, scheduler: mainQueue)
      .eraseToEffect()

    enum Action { case start, end }

    let reducer = Reduce<Void, Action>({ _, action in
      switch action {
      case .start:
        return effect.map { .end }
      case .end:
        return .none
      }
    })
    let store = Store(initialState: (), reducer: reducer)

    XCTAssertEqual(store.effectCancellables.count, 0)

    _ = store.send(.start)

    XCTAssertEqual(store.effectCancellables.count, 1)

    mainQueue.advance(by: 2)

    XCTAssertEqual(store.effectCancellables.count, 0)
  }

  func testScopedStoreReceivesUpdatesFromParent() {
    let counterReducer = Reduce<Int, Void>({ state, _ in
      state += 1
      return .none
    })

    let parentStore = Store(initialState: 0, reducer: counterReducer)
    let parentViewStore = ViewStore(parentStore)
    let childStore = parentStore.scope(state: String.init)

    var values: [String] = []
    ViewStore(childStore).publisher
      .sink(receiveValue: { values.append($0) })
      .store(in: &self.cancellables)

    XCTAssertEqual(values, ["0"])

    parentViewStore.send(())

    XCTAssertEqual(values, ["0", "1"])
  }

  func testParentStoreReceivesUpdatesFromChild() {
    let counterReducer = Reduce<Int, Void>({ state, _ in
      state += 1
      return .none
    })

    let parentStore = Store(initialState: 0, reducer: counterReducer)
    let childStore = parentStore.scope(state: String.init)
    let childViewStore = ViewStore(childStore)

    var values: [Int] = []
    ViewStore(parentStore).publisher
      .sink(receiveValue: { values.append($0) })
      .store(in: &self.cancellables)

    XCTAssertEqual(values, [0])

    childViewStore.send(())

    XCTAssertEqual(values, [0, 1])
  }

  func testScopeCallCount() {
    let counterReducer = Reduce<Int, Void>({ state, _ in
      state += 1
      return .none
    })

    var numCalls1 = 0
    _ = Store(initialState: 0, reducer: counterReducer)
      .scope(state: { (count: Int) -> Int in
        numCalls1 += 1
        return count
      })

    XCTAssertEqual(numCalls1, 1)
  }

  func testScopeCallCount2() {
    let counterReducer = Reduce<Int, Void>({ state, _ in
      state += 1
      return .none
    })

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

    let viewStore1 = ViewStore(store1)
    let viewStore2 = ViewStore(store2)
    let viewStore3 = ViewStore(store3)
    let viewStore4 = ViewStore(store4)

    XCTAssertEqual(numCalls1, 1)
    XCTAssertEqual(numCalls2, 1)
    XCTAssertEqual(numCalls3, 1)

    viewStore4.send(())

    XCTAssertEqual(numCalls1, 2)
    XCTAssertEqual(numCalls2, 2)
    XCTAssertEqual(numCalls3, 2)

    viewStore4.send(())

    XCTAssertEqual(numCalls1, 3)
    XCTAssertEqual(numCalls2, 3)
    XCTAssertEqual(numCalls3, 3)

    viewStore4.send(())

    XCTAssertEqual(numCalls1, 4)
    XCTAssertEqual(numCalls2, 4)
    XCTAssertEqual(numCalls3, 4)

    viewStore4.send(())

    XCTAssertEqual(numCalls1, 5)
    XCTAssertEqual(numCalls2, 5)
    XCTAssertEqual(numCalls3, 5)

    _ = viewStore1
    _ = viewStore2
    _ = viewStore3
  }

  func testSynchronousEffectsSentAfterSinking() {
    enum Action {
      case tap
      case next1
      case next2
      case end
    }
    var values: [Int] = []
    let counterReducer = Reduce<Void, Action>({ state, action in
      switch action {
      case .tap:
        return .merge(
          EffectTask(value: .next1),
          EffectTask(value: .next2),
          .fireAndForget { values.append(1) }
        )
      case .next1:
        return .merge(
          EffectTask(value: .end),
          .fireAndForget { values.append(2) }
        )
      case .next2:
        return .fireAndForget { values.append(3) }
      case .end:
        return .fireAndForget { values.append(4) }
      }
    })

    let store = Store(initialState: (), reducer: counterReducer)

    _ = ViewStore(store, observe: {}, removeDuplicates: ==).send(.tap)

    XCTAssertEqual(values, [1, 2, 3, 4])
  }

  func testLotsOfSynchronousActions() {
    enum Action { case incr, noop }
    let reducer = Reduce<Int, Action>({ state, action in
      switch action {
      case .incr:
        state += 1
        return state >= 100_000 ? EffectTask(value: .noop) : EffectTask(value: .incr)
      case .noop:
        return .none
      }
    })

    let store = Store(initialState: 0, reducer: reducer)
    _ = ViewStore(store, observe: { $0 }).send(.incr)
    XCTAssertEqual(ViewStore(store, observe: { $0 }).state, 100_000)
  }

  func testIfLetAfterScope() {
    struct AppState: Equatable {
      var count: Int?
    }

    let appReducer = Reduce<AppState, Int?>({ state, action in
      state.count = action
      return .none
    })

    let parentStore = Store(initialState: AppState(), reducer: appReducer)
    let parentViewStore = ViewStore(parentStore)

    // NB: This test needs to hold a strong reference to the emitted stores
    var outputs: [Int?] = []
    var stores: [Any] = []

    parentStore
      .scope(state: { $0.count })
      .ifLet(
        then: { store in
          stores.append(store)
          outputs.append(ViewStore(store, observe: { $0 }).state)
        },
        else: {
          outputs.append(nil)
        }
      )
      .store(in: &self.cancellables)

    XCTAssertEqual(outputs, [nil])

    _ = parentViewStore.send(1)
    XCTAssertEqual(outputs, [nil, 1])

    _ = parentViewStore.send(nil)
    XCTAssertEqual(outputs, [nil, 1, nil])

    _ = parentViewStore.send(1)
    XCTAssertEqual(outputs, [nil, 1, nil, 1])

    _ = parentViewStore.send(nil)
    XCTAssertEqual(outputs, [nil, 1, nil, 1, nil])

    _ = parentViewStore.send(1)
    XCTAssertEqual(outputs, [nil, 1, nil, 1, nil, 1])

    _ = parentViewStore.send(nil)
    XCTAssertEqual(outputs, [nil, 1, nil, 1, nil, 1, nil])
  }

  func testIfLetTwo() {
    let parentStore = Store(
      initialState: 0,
      reducer: Reduce<Int?, Bool>({ state, action in
        if action {
          state? += 1
          return .none
        } else {
          return .task { true }
        }
      })
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
        XCTAssertEqual(vs.state, 3)
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
      reducer: Reduce<Int, Action>({ state, action in
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
      })
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
      reducer: Reduce<Int, Int>({ state, action in
        switch action {
        case 0:
          return .merge(
            EffectTask(value: 1),
            EffectTask(value: 2),
            EffectTask(value: 3)
          )
        default:
          state = action
          return .none
        }
      })
    )

    var emissions: [Int] = []
    let viewStore = ViewStore(store, observe: { $0 })
    viewStore.publisher
      .sink { emissions.append($0) }
      .store(in: &self.cancellables)

    XCTAssertEqual(emissions, [0])

    viewStore.send(0)

    XCTAssertEqual(emissions, [0, 3])
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
    let parentReducer = Reduce<ParentState, ParentAction>({ state, action in
      handledActions.append(action)

      switch action {
      case .button:
        state.child = .init(count: nil)
        return .none

      case .child(let childCount):
        state.count = childCount
        return .none
      }
    })
    .ifLet(\.child, action: /ParentAction.child) {
      Reduce({ state, action in
        state.count = action
        return .none
      })
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

    XCTAssertEqual(handledActions, [])

    _ = ViewStore(parentStore).send(.button)
    XCTAssertEqual(
      handledActions,
      [
        .button,
        .child(2),
      ])
  }

  func testCascadingTaskCancellation() async {
    enum Action { case task, response, response1, response2 }
    let reducer = Reduce<Int, Action>({ state, action in
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
    })

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
      reducer: Reduce<Int, Action>({ state, action in
        switch action {
        case .task:
          return .fireAndForget { try await Task.never() }
        }
      })
    )

    await store.send(.task).cancel()
  }

  func testScopeCancellation() async throws {
    let neverEndingTask = Task<Void, Error> { try await Task.never() }

    let store = Store(
      initialState: (),
      reducer: Reduce<Void, Void>({ _, _ in
        .fireAndForget {
          try await neverEndingTask.value
        }
      })
    )
    let scopedStore = store.scope(state: { $0 })

    let sendTask = scopedStore.send(())
    await Task.yield()
    neverEndingTask.cancel()
    try await XCTUnwrap(sendTask).value
    XCTAssertEqual(store.effectCancellables.count, 0)
    XCTAssertEqual(scopedStore.effectCancellables.count, 0)
  }

  func testOverrideDependenciesDirectlyOnReducer() {
    struct Counter: ReducerProtocol {
      @Dependency(\.calendar) var calendar
      @Dependency(\.locale) var locale
      @Dependency(\.timeZone) var timeZone
      @Dependency(\.urlSession) var urlSession

      func reduce(into state: inout Int, action: Bool) -> EffectTask<Bool> {
        _ = self.calendar
        _ = self.locale
        _ = self.timeZone
        _ = self.urlSession
        state += action ? 1 : -1
        return .none
      }
    }

    let store = Store(
      initialState: 0,
      reducer: Counter()
        .dependency(\.calendar, Calendar(identifier: .gregorian))
        .dependency(\.locale, Locale(identifier: "en_US"))
        .dependency(\.timeZone, TimeZone(secondsFromGMT: 0)!)
        .dependency(\.urlSession, URLSession(configuration: .ephemeral))
    )

    ViewStore(store, observe: { $0 }).send(true)
  }

  func testOverrideDependenciesDirectlyOnStore() {
    struct MyReducer: ReducerProtocol {
      @Dependency(\.uuid) var uuid

      func reduce(into state: inout UUID, action: Void) -> EffectTask<Void> {
        state = self.uuid()
        return .none
      }
    }

    @Dependency(\.uuid) var uuid

    let store = Store(initialState: uuid(), reducer: MyReducer()) {
      $0.uuid = .constant(UUID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!)
    }
    let viewStore = ViewStore(store, observe: { $0 })

    XCTAssertEqual(viewStore.state, UUID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!)
  }

  func testStoreVsTestStore() async {
    struct Feature: ReducerProtocol {
      struct State: Equatable {
        var count = 0
      }
      enum Action: Equatable {
        case tap
        case response1(Int)
        case response2(Int)
        case response3(Int)
      }
      @Dependency(\.count) var count
      func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
        switch action {
        case .tap:
          return withDependencies {
            $0.count.value += 1
          } operation: {
            .task { .response1(self.count.value) }
          }
        case let .response1(count):
          state.count = count
          return withDependencies {
            $0.count.value += 1
          } operation: {
            .task { .response2(self.count.value) }
          }
        case let .response2(count):
          state.count = count
          return withDependencies {
            $0.count.value += 1
          } operation: {
            .task { .response3(self.count.value) }
          }
        case let .response3(count):
          state.count = count
          return .none
        }
      }
    }

    let testStore = TestStore(
      initialState: Feature.State(),
      reducer: Feature()
    )
    await testStore.send(.tap)
    await testStore.receive(.response1(1)) {
      $0.count = 1
    }
    await testStore.receive(.response2(1))
    await testStore.receive(.response3(1))

    let store = Store(
      initialState: Feature.State(),
      reducer: Feature()
    )
    await store.send(.tap)?.value
    XCTAssertEqual(store.state.value.count, testStore.state.count)
  }

  func testStoreVsTestStore_Publisher() async {
    struct Feature: ReducerProtocol {
      struct State: Equatable {
        var count = 0
      }
      enum Action: Equatable {
        case tap
        case response1(Int)
        case response2(Int)
        case response3(Int)
      }
      @Dependency(\.count) var count
      func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
        switch action {
        case .tap:
          return withDependencies {
            $0.count.value += 1
          } operation: {
            EffectTask.task { .response1(self.count.value) }
          }
          .eraseToEffect()
        case let .response1(count):
          state.count = count
          return withDependencies {
            $0.count.value += 1
          } operation: {
            EffectTask.task { .response2(self.count.value) }
          }
          .eraseToEffect()
        case let .response2(count):
          state.count = count
          return withDependencies {
            $0.count.value += 1
          } operation: {
            EffectTask.task { .response3(self.count.value) }
          }
          .eraseToEffect()
        case let .response3(count):
          state.count = count
          return .none
        }
      }
    }

    let testStore = TestStore(
      initialState: Feature.State(),
      reducer: Feature()
    )
    await testStore.send(.tap)
    await testStore.receive(.response1(1)) {
      $0.count = 1
    }
    await testStore.receive(.response2(1))
    await testStore.receive(.response3(1))

    let store = Store(
      initialState: Feature.State(),
      reducer: Feature()
    )
    await store.send(.tap)?.value
    XCTAssertEqual(store.state.value.count, testStore.state.count)
  }

  #if swift(>=5.7)
    func testChidlParentEffectCancellation() async throws {
      struct Child: ReducerProtocol {
        struct State: Equatable {}
        enum Action: Equatable {
          case task
          case didFinish
        }

        func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
          switch action {
          case .task:
            return .run { send in await send(.didFinish) }
          case .didFinish:
            return .none
          }
        }
      }
      struct Parent: ReducerProtocol {
        struct State: Equatable {
          var count = 0
          var child: Child.State?
        }
        enum Action: Equatable {
          case child(Child.Action)
          case delay
        }
        @Dependency(\.mainQueue) var mainQueue
        var body: Reduce<State, Action> {
          Reduce { state, action in
            switch action {
            case .child(.didFinish):
              state.child = nil
              return .task {
                try await self.mainQueue.sleep(for: .seconds(1))
                return .delay
              }
            case .child:
              return .none
            case .delay:
              state.count += 1
              return .none
            }
          }
          .ifLet(\.child, action: /Action.child) {
            Child()
          }
        }
      }

      let mainQueue = DispatchQueue.test
      let store = Store(
        initialState: Parent.State(child: Child.State()),
        reducer: Parent()
      ) {
        $0.mainQueue = mainQueue.eraseToAnyScheduler()
      }
      let viewStore = ViewStore(store)

      let childTask = viewStore.send(.child(.task))
      try await Task.sleep(nanoseconds: 100_000_000)
      XCTAssertEqual(viewStore.child, nil)

      await childTask.cancel()
      await mainQueue.advance(by: 1)
      try await Task.sleep(nanoseconds: 100_000_000)
      XCTTODO(
        """
        This fails because cancelling a child task will cancel all parent effects too.
        """)
      XCTAssertEqual(viewStore.count, 1)
    }
  #endif
}

private struct Count: TestDependencyKey {
  var value: Int
  static let liveValue = Count(value: 0)
  static let testValue = Count(value: 0)
}
extension DependencyValues {
  fileprivate var count: Count {
    get { self[Count.self] }
    set { self[Count.self] = newValue }
  }
}
