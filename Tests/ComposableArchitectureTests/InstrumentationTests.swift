import Combine
import XCTest

@testable import ComposableArchitecture

final class InstrumentationTests: XCTestCase {
  var cancellables: Set<AnyCancellable> = []

  func testNoneEffectReducer_Store() {
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
      case (_, .storeToLocal), (_, .storeDeduplicate):
        XCTFail("Scope based callbacks should not be called")
      }
    })


    let store = Store(initialState: (), reducer: Reducer<Void, Void, Void>.empty, environment: ())
    store.send((), instrumentation: inst)

    XCTAssertEqual(2, sendCalls)
    XCTAssertEqual(2, changeStateCalls)
    XCTAssertEqual(2, processCalls)
  }

  func testNoneEffectReducer_ViewStore() {
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
      case (_, .storeToLocal), (_, .storeDeduplicate):
        XCTFail("Scope based callbacks should not be called")
      }
    })

    let store = Store(initialState: (), reducer: Reducer<Void, Void, Void>.empty, environment: ())
    let viewStore = ViewStore(store, instrumentation: inst)

    viewStore.send(())

    XCTAssertEqual(2, sendCalls_vs)
    XCTAssertEqual(2, dedupCalls_vs)
    XCTAssertEqual(2, changeCalls_vs)
    XCTAssertEqual(2, sendCalls_s)
    XCTAssertEqual(2, changeStateCalls_s)
    XCTAssertEqual(2, processCalls_s)
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
      case (_, .storeToLocal), (_, .storeDeduplicate):
        XCTFail("Scope based callbacks should not be called")
      }
    })

    var reducerCount = 0
    let reducer = Reducer<Void, Void, Void> { _, _, _ in
      guard reducerCount == 0 else { return .none }
      reducerCount += 1
      return .init(value: ())
    }
    let store = Store(initialState: (), reducer: reducer, environment: ())
    let viewStore = ViewStore(store, instrumentation: inst)

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
      case (_, .storeToLocal), (_, .storeDeduplicate):
        XCTFail("Scope based callbacks should not be called")
      }
    })

    var reducerCount = 0
    let reducer = Reducer<Void, Void, Void> { _, _, _ in
      guard reducerCount == 0 else { return .none }
      reducerCount += 1
      return .init(value: ())
    }
    let store = Store(initialState: (), reducer: reducer, environment: ())
    let viewStore = ViewStore(store, instrumentation: inst)
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
    var dedupeCalls_s = 0
    var toLocalCalls_s = 0

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
      case (_, .storeToLocal):
        toLocalCalls_s += 1
      case (_, .storeDeduplicate):
        dedupeCalls_s += 1
      }
    })

    let counterReducer = Reducer<Int, Void, Void> { state, _, _ in
      state += 1
      return .none
    }

    let parentStore = Store(initialState: 0, reducer: counterReducer, environment: ())
    let parentViewStore = ViewStore(parentStore, instrumentation: inst)
    let childStore = parentStore.scope(state: String.init, instrumentation: inst)

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
    XCTAssertEqual(2, toLocalCalls_s)
    // There was no deduplication function defined
    XCTAssertEqual(0, dedupeCalls_s)
  }

  func testScopedStore_WithDedup() {
    var sendCalls_vs = 0
    var dedupCalls_vs = 0
    var changeCalls_vs = 0
    var sendCalls_s = 0
    var changeStateCalls_s = 0
    var processCalls_s = 0
    var dedupeCalls_s = 0
    var toLocalCalls_s = 0

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
      case (_, .storeToLocal):
        toLocalCalls_s += 1
      case (_, .storeDeduplicate):
        dedupeCalls_s += 1
      }
    })

    let counterReducer = Reducer<Int, Void, Void> { state, _, _ in
      state += 1
      return .none
    }

    let parentStore = Store(initialState: 0, reducer: counterReducer, environment: ())
    let parentViewStore = ViewStore(parentStore, instrumentation: inst)
    let childStore = parentStore.scope(
      state: String.init,
      action: { $0 },
      removeDuplicates: ==,
      instrumentation: inst
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
    XCTAssertEqual(2, toLocalCalls_s)
    XCTAssertEqual(2, dedupeCalls_s)
  }

  func test_tracks_viewStore_creation() {
    var viewStoreCreated: AnyObject?

    let inst = ComposableArchitecture.Instrumentation(callback: nil, viewStoreCreated: { viewStore, _, _ in
      viewStoreCreated = viewStore
    })

    let reducer = Reducer<Int, Void, Void> { _, _, _ in
      return .none
    }
    let parentStore = Store(initialState: 0, reducer: reducer, environment: ())
    let parentViewStore = ViewStore(parentStore, instrumentation: inst)

    XCTAssertIdentical(viewStoreCreated, parentViewStore)
  }
}
