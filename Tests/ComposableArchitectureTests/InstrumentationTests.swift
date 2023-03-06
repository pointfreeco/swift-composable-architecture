import Combine
import XCTest

@_spi(Internals) @testable import ComposableArchitecture

final class InstrumentationTests: XCTestCase {
  var cancellables: Set<AnyCancellable> = []

  func testNoneEffectReducer_IntStateStore() {
    var sendCalls = 0
    var changeStateCalls = 0
    var processCalls = 0
    let inst = ComposableArchitecture.Instrumentation(callback: { info, timing, kind in
      switch (timing, kind) {
      case (_, .viewStoreSend), (_, .viewStoreDeduplicate), (_, .viewStoreChangeState):
        XCTFail("ViewStore callbacks should not be called")
      case (_, .storeSend):
        sendCalls += 1
      case (_, .storeChangeState):
        changeStateCalls += 1
      case (_, .storeProcessEvent):
        processCalls += 1
      case (_, .scopedStoreToLocal), (_, .scopedStoreDeduplicate), (_, .scopedStoreChangeState):
        XCTFail("Scope based callbacks should not be called")
      }
    })

    let store = Store(initialState: 0, reducer: EmptyReducer<Int, Void>(), instrumentation: inst)
    _ = store.send(())

    XCTAssertEqual(2, sendCalls)
    XCTAssertEqual(2, changeStateCalls)
    XCTAssertEqual(2, processCalls)
  }

  func testNoneEffectReducer_IntStateViewStore() {
    var sendCalls_vs = 0
    var dedupCalls_vs = 0
    var changeCalls_vs = 0

    var sendCalls_s = 0
    var changeStateCalls_s = 0
    var processCalls_s = 0
    let inst = ComposableArchitecture.Instrumentation(callback: { info, timing, kind in
      switch (timing, kind) {
      case (_, .storeSend):
        sendCalls_s += 1
      case (_, .storeChangeState):
        changeStateCalls_s += 1
      case (_, .storeProcessEvent):
        processCalls_s += 1
      case (_, .viewStoreSend):
        sendCalls_vs += 1
      case (_, .viewStoreDeduplicate):
        dedupCalls_vs += 1
      case (_, .viewStoreChangeState):
        changeCalls_vs += 1
      case (_, .scopedStoreToLocal), (_, .scopedStoreDeduplicate), (_, .scopedStoreChangeState):
        XCTFail("Scope based callbacks should not be called")
      }
    })

    let store = Store(initialState: 0, reducer: EmptyReducer<Int, Void>(), instrumentation: inst)
    let viewStore = ViewStore(store)

    viewStore.send(())

    XCTAssertEqual(2, sendCalls_vs)
    XCTAssertEqual(2, dedupCalls_vs)
    XCTAssertEqual(2, changeCalls_vs)
    XCTAssertEqual(2, sendCalls_s)
    XCTAssertEqual(2, changeStateCalls_s)
    XCTAssertEqual(2, processCalls_s)
  }

  func testNoneEffectReducer_StatelessViewStore() {
    var sendCalls_vs = 0
    var dedupCalls_vs = 0
    var changeCalls_vs = 0
    var sendCalls_s = 0
    var changeStateCalls_s = 0
    var processCalls_s = 0

    let inst = ComposableArchitecture.Instrumentation(callback: { info, timing, kind in
      switch (timing, kind) {
      case (_, .storeSend):
        sendCalls_s += 1
      case (_, .storeChangeState):
        changeStateCalls_s += 1
      case (_, .storeProcessEvent):
        processCalls_s += 1
      case (_, .viewStoreSend):
        sendCalls_vs += 1
      case (_, .viewStoreDeduplicate):
        dedupCalls_vs += 1
      case (_, .viewStoreChangeState):
        changeCalls_vs += 1
      case (_, .scopedStoreToLocal), (_, .scopedStoreDeduplicate), (_, .scopedStoreChangeState):
        XCTFail("Scoped store callbacks should not be called")
      }
    })

    let store = Store(initialState: (), reducer: AnyReducer<(), Void, Void>.empty, environment: (), instrumentation: inst)
    let viewStore = ViewStore(store)

    viewStore.send(())
    XCTAssertEqual(2, sendCalls_vs, "We expect before and after calls")
    XCTAssertEqual(0, dedupCalls_vs, "There should be no deduping on `void` ViewStore")
    XCTAssertEqual(0, changeCalls_vs, "There should be no change calls on `void` ViewStore")
    XCTAssertEqual(2, sendCalls_s, "We expect before and after calls")
    XCTAssertEqual(2, changeStateCalls_s, "We expect before and after calls")
    XCTAssertEqual(2, processCalls_s, "We expect before and after calls")
  }

  func testEffectProducingReducer_ViewStore() {
    var sendCalls_vs = 0
    var dedupCalls_vs = 0
    var changeCalls_vs = 0
    var sendCalls_s = 0
    var changeStateCalls_s = 0
    var processCalls_s = 0

    let inst = ComposableArchitecture.Instrumentation(callback: { info, timing, kind in
      switch (timing, kind) {
      case (_, .storeSend):
        sendCalls_s += 1
      case (_, .storeChangeState):
        changeStateCalls_s += 1
      case (_, .storeProcessEvent):
        processCalls_s += 1
      case (_, .viewStoreSend):
        sendCalls_vs += 1
      case (_, .viewStoreDeduplicate):
        dedupCalls_vs += 1
      case (_, .viewStoreChangeState):
        changeCalls_vs += 1
      case (_, .scopedStoreToLocal), (_, .scopedStoreDeduplicate), (_, .scopedStoreChangeState):
        XCTFail("Scope based callbacks should not be called")
      }
    })

    var reducerCount = 0
    let store = Store<Int, Void>(
        initialState: 0,
        reducer: Reduce(internal: { state, action in
            guard reducerCount == 0 else { return .none }
            reducerCount += 1
            return .init(value: ())
        }),
        instrumentation: inst
    )
    let viewStore = ViewStore(store)

    viewStore.send(())

    XCTAssertEqual(2, sendCalls_vs)
    XCTAssertEqual(2, dedupCalls_vs)
    XCTAssertEqual(2, changeCalls_vs)
    XCTAssertEqual(2, sendCalls_s)
    XCTAssertEqual(2, changeStateCalls_s)
    // 4 because 2 for the initial action and 2 for the action sent by the reducer's effect
    XCTAssertEqual(4, processCalls_s)
  }

  func testViewStoreSendsActionOnChange() {
    var sendCalls_vs = 0
    var dedupCalls_vs = 0
    var changeCalls_vs = 0
    var sendCalls_s = 0
    var changeStateCalls_s = 0
    var processCalls_s = 0

    let inst = ComposableArchitecture.Instrumentation(callback: { info, timing, kind in
      switch (timing, kind) {
      case (_, .storeSend):
        sendCalls_s += 1
      case (_, .storeChangeState):
        changeStateCalls_s += 1
      case (_, .storeProcessEvent):
        processCalls_s += 1
      case (_, .viewStoreSend):
        sendCalls_vs += 1
      case (_, .viewStoreDeduplicate):
        dedupCalls_vs += 1
      case (_, .viewStoreChangeState):
        changeCalls_vs += 1
      case (_, .scopedStoreToLocal), (_, .scopedStoreDeduplicate), (_, .scopedStoreChangeState):
        XCTFail("Scope based callbacks should not be called")
      }
    })

    var reducerCount = 0
    let store = Store<Int, Void>(
        initialState: 0,
        reducer: Reduce(internal: { _, _ in
            guard reducerCount == 0 else { return .none }
            reducerCount += 1
            return .init(value: ())
        }),
        instrumentation: inst
    )
    let viewStore = ViewStore(store)
    viewStore.publisher
      .sink { [unowned viewStore] _ in
        viewStore.send(())
      }.store(in: &self.cancellables)

    viewStore.send(())

    // 2 for each call to ViewStore.send
    XCTAssertEqual(4, sendCalls_vs)
    // 2 for each deduplication, which happens each time the state changes
    XCTAssertEqual(4, dedupCalls_vs)
    // Only 2 because the state gets deduplicated so the view store only updates it state with the initial value
    XCTAssertEqual(2, changeCalls_vs)
    // 2 for each call to Store.send that comes from the ViewStore.send
    XCTAssertEqual(4, sendCalls_s)
    // 2 for each time the Store's state updates due to a send
    XCTAssertEqual(4, changeStateCalls_s)
    // 6 because 2 for the initial ViewStore.send, 2 for the action from the reducer, and 2 for the publisher's
    // ViewStore.send
    XCTAssertEqual(6, processCalls_s)
  }

  func testScopedStore_NoDedup() {
    var sendCalls_vs = 0
    var dedupCalls_vs = 0
    var changeCalls_vs = 0
    var sendCalls_s = 0
    var changeStateCalls_s = 0
    var processCalls_s = 0
    var scopedDedupeCalls_s = 0
    var scopedToLocalCalls_s = 0
    var scopedChangeStateCalls_s: Int = 0

    let inst = ComposableArchitecture.Instrumentation(callback: { info, timing, kind in
      switch (timing, kind) {
      case (_, .storeSend):
        sendCalls_s += 1
      case (_, .storeChangeState):
        changeStateCalls_s += 1
      case (_, .storeProcessEvent):
        processCalls_s += 1
      case (_, .viewStoreSend):
        sendCalls_vs += 1
      case (_, .viewStoreDeduplicate):
        dedupCalls_vs += 1
      case (_, .viewStoreChangeState):
        changeCalls_vs += 1
      case (_, .scopedStoreToLocal):
        scopedToLocalCalls_s += 1
      case (_, .scopedStoreDeduplicate):
        scopedDedupeCalls_s += 1
      case (_, .scopedStoreChangeState):
        scopedChangeStateCalls_s += 1
      }
    })

    let parentStore = Store<Int, Void>(
        initialState: 0,
        reducer: Reduce(internal: { state, _ in
            state += 1
            return .none
        }),
        instrumentation: inst
    )
    let parentViewStore = ViewStore(parentStore)
    let childStore = parentStore.scope(state: String.init)

    var values: [String] = []
    childStore.state
      .sink(receiveValue: { values.append($0) })
      .store(in: &self.cancellables)

    parentViewStore.send(())

    XCTAssertEqual(2, sendCalls_vs)
    XCTAssertEqual(2, dedupCalls_vs)
    // 4 because 2 for the initial value and 2 for the updated value
    XCTAssertEqual(4, changeCalls_vs)
    XCTAssertEqual(2, sendCalls_s)
    XCTAssertEqual(2, changeStateCalls_s)
    XCTAssertEqual(2, processCalls_s)
    XCTAssertEqual(2, scopedToLocalCalls_s)
    // There was no deduplication function defined
    XCTAssertEqual(0, scopedDedupeCalls_s)
    XCTAssertEqual(2, scopedChangeStateCalls_s)
  }

  func testScopedStore_WithDedup() {
    var sendCalls_vs = 0
    var dedupCalls_vs = 0
    var changeCalls_vs = 0
    var sendCalls_s = 0
    var changeStateCalls_s = 0
    var processCalls_s = 0
    var scopedDedupeCalls_s = 0
    var scopedToLocalCalls_s = 0
    var scopedChangeStateCalls_s: Int = 0

    let inst = ComposableArchitecture.Instrumentation(callback: { info, timing, kind in
      switch (timing, kind) {
      case (_, .storeSend):
        sendCalls_s += 1
      case (_, .storeChangeState):
        changeStateCalls_s += 1
      case (_, .storeProcessEvent):
        processCalls_s += 1
      case (_, .viewStoreSend):
        sendCalls_vs += 1
      case (_, .viewStoreDeduplicate):
        dedupCalls_vs += 1
      case (_, .viewStoreChangeState):
        changeCalls_vs += 1
      case (_, .scopedStoreToLocal):
        scopedToLocalCalls_s += 1
      case (_, .scopedStoreDeduplicate):
        scopedDedupeCalls_s += 1
      case (_, .scopedStoreChangeState):
        scopedChangeStateCalls_s += 1
      }
    })

    let parentStore = Store<Int, Void>(
        initialState: 0,
        reducer: Reduce(internal: { state, _ in
            state += 1
            return .none
        }),
        instrumentation: inst
    )
    let parentViewStore = ViewStore(parentStore)
    let childStore = parentStore.scope(
      state: String.init,
      action: { $0 },
      removeDuplicates: ==
    )

    var values: [String] = []
    childStore.state
      .sink(receiveValue: { values.append($0) })
      .store(in: &self.cancellables)

    parentViewStore.send(())

    XCTAssertEqual(2, sendCalls_vs)
    XCTAssertEqual(2, dedupCalls_vs)
    // 4 because 2 for the initial value and 2 for the updated value
    XCTAssertEqual(4, changeCalls_vs)
    XCTAssertEqual(2, sendCalls_s)
    XCTAssertEqual(2, changeStateCalls_s)
    XCTAssertEqual(2, processCalls_s)
    // Initial value then update
    XCTAssertEqual(2, scopedToLocalCalls_s)
    XCTAssertEqual(2, scopedDedupeCalls_s)
    XCTAssertEqual(2, scopedChangeStateCalls_s)
  }

  func test_tracks_viewStore_creation() {
    var viewStoreCreated: AnyObject?

    let inst = ComposableArchitecture.Instrumentation(callback: nil, viewStoreCreated: { viewStore, _, _, _, _ in
      viewStoreCreated = viewStore
    })

    let parentStore = Store<Int, Void>(
        initialState: 0,
        reducer: EmptyReducer(),
        instrumentation: inst
    )
    let parentViewStore = ViewStore(parentStore)

    XCTAssertIdentical(viewStoreCreated, parentViewStore)
  }

  func test_tracks_store_creation() {
    var storeCreated: AnyObject?

    let inst = ComposableArchitecture.Instrumentation(callback: nil, storeCreated: { store, _, _, _, _ in
        storeCreated = store
    })

    let parentStore = Store<Int, Void>(
        initialState: 0,
        reducer: EmptyReducer(),
        instrumentation: inst
    )

    XCTAssertIdentical(storeCreated, parentStore)
  }
}
