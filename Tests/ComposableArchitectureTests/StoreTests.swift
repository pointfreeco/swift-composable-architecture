@preconcurrency import Combine
@_spi(Internals) import ComposableArchitecture
import XCTest

#if canImport(Testing)
  import Testing
#endif

final class StoreTests: BaseTCATestCase {
  var cancellables: Set<AnyCancellable> = []

  @MainActor
  func testCancellableIsRemovedOnImmediatelyCompletingEffect() {
    let store = Store<Void, Void>(initialState: ()) {}

    XCTAssertEqual(store.effectCancellables.count, 0)

    store.send(())

    XCTAssertEqual(store.effectCancellables.count, 0)
  }

  @MainActor
  func testCancellableIsRemovedWhenEffectCompletes() {
    let mainQueue = DispatchQueue.test

    enum Action { case start, end }

    let reducer = Reduce<Void, Action>({ _, action in
      switch action {
      case .start:
        return .publisher {
          Just(.end)
            .delay(for: 1, scheduler: mainQueue)
        }
      case .end:
        return .none
      }
    })
    let store = Store(initialState: ()) { reducer }

    XCTAssertEqual(store.effectCancellables.count, 0)

    store.send(.start)

    XCTAssertEqual(store.effectCancellables.count, 1)

    mainQueue.advance(by: 2)

    XCTAssertEqual(store.effectCancellables.count, 0)
  }

  @available(*, deprecated)
  @MainActor
  func testScopedStoreReceivesUpdatesFromParent() {
    let counterReducer = Reduce<Int, Void>({ state, _ in
      state += 1
      return .none
    })

    let parentStore = Store(initialState: 0) { counterReducer }
    let parentViewStore = ViewStore(parentStore, observe: { $0 })
    let childStore = parentStore.scope(state: String.init, action: { $0 })

    var values: [String] = []
    ViewStore(childStore, observe: { $0 })
      .publisher
      .sink(receiveValue: { values.append($0) })
      .store(in: &self.cancellables)

    XCTAssertEqual(values, ["0"])

    parentViewStore.send(())

    XCTAssertEqual(values, ["0", "1"])
  }

  @available(*, deprecated)
  @MainActor
  func testParentStoreReceivesUpdatesFromChild() {
    let counterReducer = Reduce<Int, Void>({ state, _ in
      state += 1
      return .none
    })

    let parentStore = Store(initialState: 0) { counterReducer }
    let childStore = parentStore.scope(state: String.init, action: { $0 })
    let childViewStore = ViewStore(childStore, observe: { $0 })

    var values: [Int] = []
    ViewStore(parentStore, observe: { $0 })
      .publisher
      .sink(receiveValue: { values.append($0) })
      .store(in: &self.cancellables)

    XCTAssertEqual(values, [0])

    childViewStore.send(())

    XCTAssertEqual(values, [0, 1])
  }

  @available(*, deprecated)
  @MainActor
  func testScopeCallCount_OneLevel_NoSubscription() {
    var numCalls1 = 0
    let store = Store<Int, Void>(initialState: 0) {}
      .scope(
        state: { (count: Int) -> Int in
          numCalls1 += 1
          return count
        },
        action: { $0 }
      )

    XCTAssertEqual(numCalls1, 0)
    store.send(())
    XCTAssertEqual(numCalls1, 0)
  }

  @available(*, deprecated)
  @MainActor
  func testScopeCallCount_OneLevel_Subscribing() {
    var numCalls1 = 0
    let store = Store<Int, Void>(initialState: 0) {}
      .scope(
        state: { (count: Int) -> Int in
          numCalls1 += 1
          return count
        },
        action: { $0 }
      )
    let _ = store.publisher.sink { _ in }

    XCTAssertEqual(numCalls1, 1)
    store.send(())
    XCTAssertEqual(numCalls1, 1)
  }

  @available(*, deprecated)
  @MainActor
  func testScopeCallCount_TwoLevels_Subscribing() {
    var numCalls1 = 0
    var numCalls2 = 0
    let store = Store<Int, Void>(initialState: 0) {}
      .scope(
        state: { (count: Int) -> Int in
          numCalls1 += 1
          return count
        },
        action: { $0 }
      )
      .scope(
        state: { (count: Int) -> Int in
          numCalls2 += 1
          return count
        },
        action: { $0 }
      )
    let _ = store.publisher.sink { _ in }

    XCTAssertEqual(numCalls1, 1)
    XCTAssertEqual(numCalls2, 1)
    store.send(())
    XCTAssertEqual(numCalls1, 1)
    XCTAssertEqual(numCalls2, 1)
  }

  @available(*, deprecated)
  @MainActor
  func testScopeCallCount_ThreeLevels_ViewStoreSubscribing() {
    var numCalls1 = 0
    var numCalls2 = 0
    var numCalls3 = 0

    let store1 = Store<Int, Void>(initialState: 0) {}
    let store2 =
      store1
      .scope(
        state: { (count: Int) -> Int in
          numCalls1 += 1
          return count
        },
        action: { $0 }
      )
    let store3 =
      store2
      .scope(
        state: { (count: Int) -> Int in
          numCalls2 += 1
          return count
        },
        action: { $0 }
      )
    let store4 =
      store3
      .scope(
        state: { (count: Int) -> Int in
          numCalls3 += 1
          return count
        },
        action: { $0 }
      )

    let viewStore1 = ViewStore(store1, observe: { $0 })
    let viewStore2 = ViewStore(store2, observe: { $0 })
    let viewStore3 = ViewStore(store3, observe: { $0 })
    let viewStore4 = ViewStore(store4, observe: { $0 })
    defer {
      _ = viewStore1
      _ = viewStore2
      _ = viewStore3
      _ = viewStore4
    }

    XCTAssertEqual(numCalls1, 6)
    XCTAssertEqual(numCalls2, 4)
    XCTAssertEqual(numCalls3, 2)

    viewStore4.send(())

    XCTAssertEqual(numCalls1, 9)
    XCTAssertEqual(numCalls2, 6)
    XCTAssertEqual(numCalls3, 3)

    viewStore4.send(())

    XCTAssertEqual(numCalls1, 12)
    XCTAssertEqual(numCalls2, 8)
    XCTAssertEqual(numCalls3, 4)

    viewStore4.send(())

    XCTAssertEqual(numCalls1, 15)
    XCTAssertEqual(numCalls2, 10)
    XCTAssertEqual(numCalls3, 5)

    viewStore4.send(())

    XCTAssertEqual(numCalls1, 18)
    XCTAssertEqual(numCalls2, 12)
    XCTAssertEqual(numCalls3, 6)
  }

  @MainActor
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
          .send(.next1),
          .send(.next2),
          .publisher {
            values.append(1)
            return Empty(outputType: Action.self, failureType: Never.self)
          }
        )
      case .next1:
        return .merge(
          .send(.end),
          .publisher {
            values.append(2)
            return Empty(outputType: Action.self, failureType: Never.self)
          }
        )
      case .next2:
        return .publisher {
          values.append(3)
          return Empty(outputType: Action.self, failureType: Never.self)
        }
      case .end:
        return .publisher {
          values.append(4)
          return Empty(outputType: Action.self, failureType: Never.self)
        }
      }
    })

    let store = Store(initialState: ()) { counterReducer }

    _ = ViewStore(store, observe: {}, removeDuplicates: ==).send(.tap)

    XCTAssertEqual(values, [1, 2, 3, 4])
  }

  @MainActor
  func testLotsOfSynchronousActions() {
    enum Action { case incr, noop }
    let reducer = Reduce<Int, Action>({ state, action in
      switch action {
      case .incr:
        state += 1
        return .send(state >= 100_000 ? .noop : .incr)
      case .noop:
        return .none
      }
    })

    let store = Store(initialState: 0) { reducer }
    _ = ViewStore(store, observe: { $0 }).send(.incr)
    XCTAssertEqual(ViewStore(store, observe: { $0 }).state, 100_000)
  }

  @available(*, deprecated)
  @MainActor
  func testIfLetAfterScope() {
    struct AppState: Equatable {
      var count: Int?
    }

    let appReducer = Reduce<AppState, Int?>({ state, action in
      state.count = action
      return .none
    })

    let parentStore = Store(initialState: AppState()) { appReducer }
    let parentViewStore = ViewStore(parentStore, observe: { $0 })

    // NB: This test needs to hold a strong reference to the emitted stores
    var outputs: [Int?] = []
    var stores: [Any] = []

    parentStore
      .scope(state: { $0.count }, action: { $0 })
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

  @MainActor
  func testIfLetTwo() {
    let parentStore = Store(initialState: 0) {
      Reduce<Int?, Bool> { state, action in
        if action {
          state? += 1
          return .none
        } else {
          return .run { send in await send(true) }
        }
      }
    }

    parentStore
      .ifLet(then: { childStore in
        let vs = ViewStore(childStore, observe: { $0 })

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

  @MainActor
  func testActionQueuing() async {
    let subject = PassthroughSubject<Void, Never>()

    enum Action: Equatable {
      case incrementTapped
      case `init`
      case doIncrement
    }

    let store = TestStore(initialState: 0) {
      Reduce<Int, Action> { state, action in
        switch action {
        case .incrementTapped:
          subject.send()
          return .none

        case .`init`:
          return .publisher { subject.map { .doIncrement } }

        case .doIncrement:
          state += 1
          return .none
        }
      }
    }

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

  @MainActor
  func testCoalesceSynchronousActions() {
    let store = Store(initialState: 0) {
      Reduce<Int, Int> { state, action in
        switch action {
        case 0:
          return .merge(
            .send(1),
            .send(2),
            .send(3)
          )
        default:
          state = action
          return .none
        }
      }
    }

    var emissions: [Int] = []
    let viewStore = ViewStore(store, observe: { $0 })
    viewStore.publisher
      .sink { emissions.append($0) }
      .store(in: &self.cancellables)

    XCTAssertEqual(emissions, [0])

    viewStore.send(0)

    XCTAssertEqual(emissions, [0, 3])
  }

  @available(*, deprecated)
  @MainActor
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

      case let .child(childCount):
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

    let parentStore = Store(initialState: ParentState()) {
      parentReducer
    }

    parentStore
      .scope(
        state: \.child,
        action: ParentAction.child
      )
      .ifLet { childStore in
        ViewStore(childStore, observe: { $0 }).send(2)
      }
      .store(in: &cancellables)

    XCTAssertEqual(handledActions, [])

    _ = ViewStore(parentStore, observe: { $0 }).send(.button)
    XCTAssertEqual(
      handledActions,
      [
        .button,
        .child(2),
      ])
  }

  func testCascadingTaskCancellation() async {
    enum Action { case task, response, response1, response2 }
    let store = await TestStore(initialState: 0) {
      Reduce<Int, Action> { state, action in
        switch action {
        case .task:
          return .run { send in await send(.response) }
        case .response:
          return .merge(
            .run { _ in try await Task.never() },
            .run { send in await send(.response1) }
          )
        case .response1:
          return .merge(
            .run { _ in try await Task.never() },
            .run { send in await send(.response2) }
          )
        case .response2:
          return .run { _ in try await Task.never() }
        }
      }
    }

    let task = await store.send(.task)
    await store.receive(.response)
    await store.receive(.response1)
    await store.receive(.response2)
    await task.cancel()
  }

  func testTaskCancellationEmpty() async {
    enum Action { case task }

    let store = await TestStore(initialState: 0) {
      Reduce<Int, Action> { state, action in
        switch action {
        case .task:
          return .run { _ in try await Task.never() }
        }
      }
    }

    await store.send(.task).cancel()
  }

  @available(*, deprecated)
  @MainActor
  func testScopeCancellation() async throws {
    let neverEndingTask = Task<Void, any Error> { try await Task.never() }

    let store = Store(initialState: ()) {
      Reduce<Void, Void> { _, _ in
        .run { _ in
          try await neverEndingTask.value
        }
      }
    }
    let scopedStore = store.scope(state: { $0 }, action: { $0 })

    let sendTask: Task? = scopedStore.send(())
    await Task.yield()
    neverEndingTask.cancel()
    try await XCTUnwrap(sendTask).value
    XCTAssertEqual(store.effectCancellables.count, 0)
    XCTAssertEqual(scopedStore.effectCancellables.count, 0)
  }

  @Reducer
  fileprivate struct Feature_testOverrideDependenciesDirectlyOnReducer {
    @Dependency(\.calendar) var calendar
    @Dependency(\.locale) var locale
    @Dependency(\.timeZone) var timeZone
    @Dependency(\.urlSession) var urlSession
    var body: some Reducer<Int, Bool> {
      Reduce { state, action in
        _ = self.calendar
        _ = self.locale
        _ = self.timeZone
        _ = self.urlSession
        state += action ? 1 : -1
        return .none
      }
    }
  }

  @MainActor
  func testOverrideDependenciesDirectlyOnReducer() {
    let store = Store(initialState: 0) {
      Feature_testOverrideDependenciesDirectlyOnReducer()
        .dependency(\.calendar, Calendar(identifier: .gregorian))
        .dependency(\.locale, Locale(identifier: "en_US"))
        .dependency(\.timeZone, TimeZone(secondsFromGMT: 0)!)
        .dependency(\.urlSession, URLSession(configuration: .ephemeral))
    }

    ViewStore(store, observe: { $0 }).send(true)
  }

  @Reducer
  fileprivate struct Feature_testOverrideDependenciesDirectlyOnStore {
    @Dependency(\.uuid) var uuid
    var body: some Reducer<UUID, Void> {
      Reduce { state, action in
        state = self.uuid()
        return .none
      }
    }
  }

  @MainActor
  func testOverrideDependenciesDirectlyOnStore() {
    @Dependency(\.uuid) var uuid
    let store = Store(initialState: uuid()) {
      Feature_testOverrideDependenciesDirectlyOnStore()
    } withDependencies: {
      $0.uuid = .constant(UUID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!)
    }
    let viewStore = ViewStore(store, observe: { $0 })

    XCTAssertEqual(viewStore.state, UUID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!)
  }

  @Reducer
  fileprivate struct Feature_testStoreVsTestStore {
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
    var body: some Reducer<State, Action> {
      Reduce { state, action in
        switch action {
        case .tap:
          return withDependencies {
            $0.count.value += 1
          } operation: {
            .run { send in await send(.response1(self.count.value)) }
          }
        case let .response1(count):
          state.count = count
          return withDependencies {
            $0.count.value += 1
          } operation: {
            .run { send in await send(.response2(self.count.value)) }
          }
        case let .response2(count):
          state.count = count
          return withDependencies {
            $0.count.value += 1
          } operation: {
            .run { send in await send(.response3(self.count.value)) }
          }
        case let .response3(count):
          state.count = count
          return .none
        }
      }
    }
  }

  @MainActor
  func testStoreVsTestStore() async {
    let testStore = TestStore(initialState: Feature_testStoreVsTestStore.State()) {
      Feature_testStoreVsTestStore()
    }
    await testStore.send(.tap)
    await testStore.receive(.response1(1)) {
      $0.count = 1
    }
    await testStore.receive(.response2(1))
    await testStore.receive(.response3(1))

    let store = Store(initialState: Feature_testStoreVsTestStore.State()) {
      Feature_testStoreVsTestStore()
    }
    await store.send(.tap)?.value
    XCTAssertEqual(store.withState(\.count), testStore.state.count)
  }

  @Reducer
  fileprivate struct Feature_testStoreVsTestStore_Publisher {
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
    var body: some Reducer<State, Action> {
      Reduce { state, action in
        switch action {
        case .tap:
          return withDependencies {
            $0.count.value += 1
          } operation: {
            .run { send in await send(.response1(self.count.value)) }
          }
        case let .response1(count):
          state.count = count
          return withDependencies {
            $0.count.value += 1
          } operation: {
            .run { send in await send(.response2(self.count.value)) }
          }
        case let .response2(count):
          state.count = count
          return withDependencies {
            $0.count.value += 1
          } operation: {
            .run { send in await send(.response3(self.count.value)) }
          }
        case let .response3(count):
          state.count = count
          return .none
        }
      }
    }
  }

  @MainActor
  func testStoreVsTestStore_Publisher() async {
    let testStore = TestStore(initialState: Feature_testStoreVsTestStore_Publisher.State()) {
      Feature_testStoreVsTestStore_Publisher()
    }
    await testStore.send(.tap)
    await testStore.receive(.response1(1)) {
      $0.count = 1
    }
    await testStore.receive(.response2(1))
    await testStore.receive(.response3(1))

    let store = Store(initialState: Feature_testStoreVsTestStore_Publisher.State()) {
      Feature_testStoreVsTestStore_Publisher()
    }
    await store.send(.tap)?.value
    XCTAssertEqual(store.withState(\.count), testStore.state.count)
  }

  @Reducer
  struct Child_testChildParentEffectCancellation {
    struct State: Equatable {}
    enum Action: Equatable {
      case task
      case didFinish
    }

    var body: some Reducer<State, Action> {
      Reduce { state, action in
        switch action {
        case .task:
          return .run { send in await send(.didFinish) }
        case .didFinish:
          return .none
        }
      }
    }
  }
  @Reducer
  struct Parent_testChildParentEffectCancellation {
    struct State: Equatable {
      var count = 0
      var child: Child_testChildParentEffectCancellation.State?
    }
    enum Action: Equatable {
      case child(Child_testChildParentEffectCancellation.Action)
      case delay
    }
    @Dependency(\.mainQueue) var mainQueue
    var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .child(.didFinish):
          state.child = nil
          return .run { send in
            try await self.mainQueue.sleep(for: .seconds(1))
            await send(.delay)
          }
        case .child:
          return .none
        case .delay:
          state.count += 1
          return .none
        }
      }
      .ifLet(\.child, action: \.child) {
        Child_testChildParentEffectCancellation()
      }
    }
  }

  @MainActor
  func testChildParentEffectCancellation() async throws {
    let mainQueue = DispatchQueue.test
    let store = Store(
      initialState: Parent_testChildParentEffectCancellation.State(
        child: .init()
      )
    ) {
      Parent_testChildParentEffectCancellation()
    } withDependencies: {
      $0.mainQueue = mainQueue.eraseToAnyScheduler()
    }
    let viewStore = ViewStore(store, observe: { $0 })

    let childTask = viewStore.send(.child(.task))
    try await Task.sleep(nanoseconds: 100_000_000)
    XCTAssertEqual(viewStore.child, nil)

    childTask.cancel()
    await mainQueue.advance(by: 1)
    try await Task.sleep(nanoseconds: 100_000_000)
    XCTTODO(
      """
      This fails because cancelling a child task will cancel all parent effects too.
      """
    )
    XCTAssertEqual(viewStore.count, 1)
  }

  @MainActor
  func testInit_InitialState_WithDependencies() async {
    struct Feature: Reducer {
      struct State: Equatable {
        var date: Date
        init() {
          @Dependency(\.date) var date
          self.date = date()
        }
      }
      enum Action: Equatable {}
      var body: some Reducer<State, Action> {
        EmptyReducer()
      }
    }

    let store = Store(initialState: Feature.State()) {
      Feature()
    } withDependencies: {
      $0.date = .constant(Date(timeIntervalSinceReferenceDate: 1_234_567_890))
    }

    XCTAssertEqual(store.withState(\.date), Date(timeIntervalSinceReferenceDate: 1_234_567_890))
  }

  @MainActor
  func testInit_ReducerBuilder_WithDependencies() async {
    struct Feature: Reducer {
      let date: Date
      struct State: Equatable { var date: Date? }
      enum Action: Equatable { case tap }
      var body: some Reducer<State, Action> {
        Reduce { state, _ in
          state.date = self.date
          return .none
        }
      }
    }

    @Dependency(\.date) var date
    let store = Store(initialState: Feature.State()) {
      Feature(date: date())
    } withDependencies: {
      $0.date = .constant(Date(timeIntervalSinceReferenceDate: 1_234_567_890))
    }

    store.send(.tap)
    XCTAssertEqual(store.withState(\.date), Date(timeIntervalSinceReferenceDate: 1_234_567_890))
  }

  @Reducer
  struct Feature_testPresentationScope {
    struct State: Equatable {
      var count = 0
      @PresentationState var child: State?
    }
    enum Action {
      case child(PresentationAction<Action>)
      case tap
    }
    var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .child:
          return .none
        case .tap:
          state.count += 1
          return .none
        }
      }
      .ifLet(\.$child, action: \.child) {
        Feature_testPresentationScope()
      }
    }
  }

  @available(*, deprecated)
  @MainActor
  func testPresentationScope() async {
    let store = Store(
      initialState: Feature_testPresentationScope.State(
        child: .init(child: .init()))
    ) {
      Feature_testPresentationScope()
    }
    var removeDuplicatesCount1 = 0
    var stateScopeCount1 = 0
    var viewStoreCount1 = 0
    var removeDuplicatesCount2 = 0
    var storeStateCount1 = 0
    var stateScopeCount2 = 0
    var viewStoreCount2 = 0
    var storeStateCount2 = 0
    let childStore1 = store.scope(
      state: {
        stateScopeCount1 += 1
        return $0.$child
      },
      action: { .child($0) }
    )
    let childViewStore1 = ViewStore(
      childStore1,
      observe: { $0 },
      removeDuplicates: { lhs, rhs in
        removeDuplicatesCount1 += 1
        return lhs == rhs
      }
    )
    childViewStore1.objectWillChange
      .sink { _ in viewStoreCount1 += 1 }
      .store(in: &self.cancellables)
    childStore1.publisher
      .sink { _ in storeStateCount1 += 1 }
      .store(in: &self.cancellables)
    let childStore2 = store.scope(
      state: {
        stateScopeCount2 += 1
        return $0.$child
      },
      action: { .child($0) }
    )
    let childViewStore2 = ViewStore(
      childStore2,
      observe: { $0 },
      removeDuplicates: { lhs, rhs in
        removeDuplicatesCount2 += 1
        return lhs == rhs
      }
    )
    childViewStore2.objectWillChange
      .sink { _ in viewStoreCount2 += 1 }
      .store(in: &self.cancellables)
    childStore2.publisher
      .sink { _ in storeStateCount2 += 1 }
      .store(in: &self.cancellables)

    store.send(.tap)
    XCTAssertEqual(removeDuplicatesCount1, 1)
    XCTAssertEqual(stateScopeCount1, 5)
    XCTAssertEqual(viewStoreCount1, 0)
    XCTAssertEqual(storeStateCount1, 2)
    XCTAssertEqual(removeDuplicatesCount2, 1)
    XCTAssertEqual(stateScopeCount2, 5)
    XCTAssertEqual(viewStoreCount2, 0)
    XCTAssertEqual(storeStateCount2, 2)
    store.send(.tap)
    XCTAssertEqual(removeDuplicatesCount1, 2)
    XCTAssertEqual(stateScopeCount1, 7)
    XCTAssertEqual(viewStoreCount1, 0)
    XCTAssertEqual(storeStateCount1, 3)
    XCTAssertEqual(removeDuplicatesCount2, 2)
    XCTAssertEqual(stateScopeCount2, 7)
    XCTAssertEqual(viewStoreCount2, 0)
    XCTAssertEqual(storeStateCount2, 3)

    store.send(.child(.dismiss))
    _ = (childViewStore1, childViewStore2, childStore1, childStore2)
  }

  @MainActor
  func testReEntrantAction() async {
    struct Feature: Reducer {
      let subject = PassthroughSubject<Void, Never>()

      struct State: Equatable {
        var count = 0
        var isOn = false
        var subjectCount = 0
      }
      enum Action: Equatable {
        case onAppear
        case subjectEmitted
        case tap
      }
      var body: some ReducerOf<Self> {
        Reduce { state, action in
          switch action {
          case .onAppear:
            return .publisher {
              subject.map { .subjectEmitted }
            }
          case .subjectEmitted:
            if state.isOn {
              state.count += 1
            }
            state.subjectCount += 1
            return .none
          case .tap:
            state.isOn = true
            subject.send()
            state.isOn = false
            return .none
          }
        }
      }
    }

    let store = Store(initialState: Feature.State()) {
      Feature()
    }
    store.send(.onAppear)
    store.send(.tap)
    try? await Task.sleep(nanoseconds: 1_000_000)
    XCTAssertEqual(
      store.withState { $0 },
      Feature.State(count: 0, isOn: false, subjectCount: 1)
    )
  }

  @Reducer
  struct InvalidatedStoreScopeParentFeature: Reducer {
    @ObservableState
    struct State {
      @Presents var child: InvalidatedStoreScopeChildFeature.State?
    }
    enum Action {
      case child(PresentationAction<InvalidatedStoreScopeChildFeature.Action>)
      case tap
    }
    var body: some ReducerOf<Self> {
      EmptyReducer()
        .ifLet(\.$child, action: \.child) {
          InvalidatedStoreScopeChildFeature()
        }
    }
  }
  @Reducer
  struct InvalidatedStoreScopeChildFeature: Reducer {
    @ObservableState
    struct State {
      @Presents var grandchild: InvalidatedStoreScopeGrandchildFeature.State?
    }
    enum Action {
      case grandchild(PresentationAction<InvalidatedStoreScopeGrandchildFeature.Action>)
    }
    var body: some ReducerOf<Self> {
      EmptyReducer()
        .ifLet(\.$grandchild, action: \.grandchild) {
          InvalidatedStoreScopeGrandchildFeature()
        }
    }
  }
  @Reducer
  struct InvalidatedStoreScopeGrandchildFeature: Reducer {
    struct State {}
    enum Action {}
    var body: some ReducerOf<Self> { EmptyReducer() }
  }

  //  #if !os(visionOS)
  //    @MainActor
  //    func testInvalidatedStoreScope() async throws {
  //      @Perception.Bindable var store = Store(
  //        initialState: InvalidatedStoreScopeParentFeature.State(
  //          child: InvalidatedStoreScopeChildFeature.State(
  //            grandchild: InvalidatedStoreScopeGrandchildFeature.State()
  //          )
  //        )
  //      ) {
  //        InvalidatedStoreScopeParentFeature()
  //      }
  //      store.send(.tap)
  //
  //      @Perception.Bindable var childStore = store.scope(state: \.child, action: \.child)!
  //      let grandchildStoreBinding = $childStore.scope(state: \.grandchild, action: \.grandchild)
  //
  //      store.send(.child(.dismiss))
  //      grandchildStoreBinding.wrappedValue = nil
  //    }
  //  #endif

  @MainActor
  func testSurroundingDependencies() {
    let store = withDependencies {
      $0.uuid = .incrementing
    } operation: {
      Store<UUID, Void>(initialState: UUID()) {
        Reduce { state, _ in
          @Dependency(\.uuid) var uuid
          state = uuid()
          return .none
        }
      }
    }

    store.send(())
    XCTAssertEqual(
      store.withState { $0 },
      UUID(0)
    )
    store.send(())
    XCTAssertEqual(
      store.withState { $0 },
      UUID(1)
    )
  }

  @MainActor
  func testStorePublisherRemovesSubscriptionOnCancel() {
    let store = Store<Void, Void>(initialState: ()) {}
    weak var subscription: AnyObject?
    let cancellable = store.publisher
      .handleEvents(receiveSubscription: { subscription = $0 as AnyObject })
      .sink { _ in }
    XCTAssertNotNil(subscription)
    cancellable.cancel()
    XCTAssertNil(subscription)
  }

  @MainActor
  func testSubscriptionOwnsStorePublisher() {
    var store: Store<Void, Void>? = Store(initialState: ()) {}
    weak var weakStore = store
    let cancellable = store!.publisher
      .sink { _ in }
    store = nil
    XCTAssertNotNil(weakStore)
    cancellable.cancel()
    XCTAssertNil(weakStore)
  }

  @MainActor
  func testSharedMutation() async {
    XCTTODO(
      """
      Ideally this will pass in 2.0 but it's a breaking change for test stores to not eagerly \
      process all received actions.
      """
    )

    let store = TestStore(initialState: TestSharedMutation.State()) {
      TestSharedMutation()
    }
    await store.send(.tap)
    await store.receive(.response) {
      $0.$bool.withLock { $0 = true }
    }
  }
  @Reducer
  struct TestSharedMutation {
    struct State: Equatable {
      @Shared(value: false) var bool
    }
    enum Action {
      case tap
      case response
    }
    var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .tap:
          return .send(.response)
        case .response:
          state.$bool.withLock { $0.toggle() }
          return .none
        }
      }
    }
  }

  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  @MainActor func testRootStoreCancellationIsolation() async throws {
    let clock = TestClock()
    let store1 = Store(initialState: RootStoreCancellationIsolation.State()) {
      RootStoreCancellationIsolation()
    } withDependencies: {
      $0.continuousClock = clock
    }
    let store2 = Store(initialState: RootStoreCancellationIsolation.State()) {
      RootStoreCancellationIsolation()
    } withDependencies: {
      $0.continuousClock = clock
    }
    let task1 = store1.send(.tap)
    let task2 = store2.send(.tap)
    try await Task.sleep(for: .seconds(1))
    store2.send(.cancelButtonTapped)
    await clock.advance()
    await task1.finish()
    await task2.finish()
    XCTAssertEqual(store1.count, 42)
    XCTAssertEqual(store2.count, 0)
  }

  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  @MainActor func testRootStoreCancellationIsolation_TestStore() async throws {
    let clock = TestClock()
    let store1 = TestStore(initialState: RootStoreCancellationIsolation.State()) {
      RootStoreCancellationIsolation()
    } withDependencies: {
      $0.continuousClock = clock
    }
    let store2 = TestStore(initialState: RootStoreCancellationIsolation.State()) {
      RootStoreCancellationIsolation()
    } withDependencies: {
      $0.continuousClock = clock
    }
    await store1.send(.tap)
    await store2.send(.tap)
    await store2.send(.cancelButtonTapped)
    await clock.advance()
    await store1.receive(\.response) {
      $0.count = 42
    }
  }

  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  @Reducer struct RootStoreCancellationIsolation {
    @ObservableState struct State: Equatable {
      var count = 0
    }
    enum Action {
      case cancelButtonTapped
      case response(Int)
      case tap
    }
    @Dependency(\.continuousClock) var clock
    enum CancelID { case effect }
    var body: some ReducerOf<Self> {
      Reduce<State, Action> { state, action in
        switch action {
        case .cancelButtonTapped:
          return .cancel(id: CancelID.effect)
        case .response(let value):
          state.count = value
          return .none
        case .tap:
          return .run { send in
            try await clock.sleep(for: .seconds(0))
            await send(.response(42))
          }
          .cancellable(id: CancelID.effect)
        }
      }
    }
  }
}

#if canImport(Testing)
  @Suite
  struct ModernStoreTests {
    @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
    @Reducer
    fileprivate struct TaskTreeFeature {
      let clock: TestClock<Duration>
      @ObservableState
      struct State { var count = 0 }
      enum Action { case tap, response1, response2 }
      var body: some ReducerOf<Self> {
        Reduce { state, action in
          switch action {
          case .tap:
            return Effect.run { send in
              await send(.response1)
            }
          case .response1:
            state.count = 42
            return Effect.run { send in
              try await clock.sleep(for: .seconds(1))
              await send(.response2)
            }
          case .response2:
            state.count = 1729
            return .none
          }
        }
      }
    }

    @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
    @MainActor
    @Test
    func cancellation() async throws {
      let clock = TestClock()
      let store = Store(initialState: TaskTreeFeature.State()) { TaskTreeFeature(clock: clock) }
      let task = store.send(.tap)
      try await Task.sleep(for: .seconds(0.1))
      #expect(store.count == 42)
      task.cancel()
      await clock.run()
      withKnownIssue("Cancelling the root effect should not cancel the child effects.") {
        #expect(store.count == 1729)
      }
    }
  }
#endif

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
