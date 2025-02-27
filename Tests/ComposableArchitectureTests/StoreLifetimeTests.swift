import Combine
@_spi(Logging) import ComposableArchitecture
import XCTest

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
final class StoreLifetimeTests: BaseTCATestCase {
  @available(*, deprecated)
  @MainActor
  func testStoreCaching() {
    let grandparentStore = Store(initialState: Grandparent.State()) {
      Grandparent()
    }
    let parentStore = grandparentStore.scope(state: \.child, action: \.child)
    XCTAssertTrue(parentStore === grandparentStore.scope(state: \.child, action: \.child))
    XCTAssertFalse(
      parentStore === grandparentStore.scope(state: { $0.child }, action: { .child($0) })
    )
    let childStore = parentStore.scope(state: \.child, action: \.child)
    XCTAssertTrue(childStore === parentStore.scope(state: \.child, action: \.child))
    XCTAssertFalse(
      childStore === parentStore.scope(state: { $0.child }, action: { .child($0) })
    )
  }

  @available(*, deprecated)
  @MainActor
  func testStoreInvalidation() {
    let grandparentStore = Store(initialState: Grandparent.State()) {
      Grandparent()
    }
    var parentStore: Store! = grandparentStore.scope(state: { $0.child }, action: { .child($0) })
    let childStore = parentStore.scope(state: \.child, action: \.child)

    childStore.send(.tap)
    XCTAssertEqual(1, grandparentStore.withState(\.child.child.count))
    XCTAssertEqual(1, parentStore.withState(\.child.count))
    XCTAssertEqual(1, childStore.withState(\.count))
    grandparentStore.send(.incrementGrandchild)
    XCTAssertEqual(2, grandparentStore.withState(\.child.child.count))
    XCTAssertEqual(2, parentStore.withState(\.child.count))
    XCTAssertEqual(2, childStore.withState(\.count))

    parentStore = nil

    childStore.send(.tap)
    XCTAssertEqual(3, grandparentStore.withState(\.child.child.count))
    XCTAssertEqual(3, childStore.withState(\.count))
    grandparentStore.send(.incrementGrandchild)
    XCTAssertEqual(4, grandparentStore.withState(\.child.child.count))
    XCTAssertEqual(4, childStore.withState(\.count))
  }

  #if DEBUG
    @MainActor
    func testStoreDeinit() {
      Logger.shared.isEnabled = true
      do {
        let store = Store<Void, Void>(initialState: ()) {}
        _ = store
      }

      XCTAssertEqual(
        Logger.shared.logs,
        [
          "Store<(), ()>.init",
          "Store<(), ()>.deinit",
        ]
      )
    }

    @MainActor
    func testStoreDeinit_RunningEffect() async {
      Logger.shared.isEnabled = true
      let effectFinished = self.expectation(description: "Effect finished")
      do {
        let store = Store<Void, Void>(initialState: ()) {
          Reduce { state, _ in
            .run { _ in
              try? await Task.never()
              effectFinished.fulfill()
            }
          }
        }
        store.send(())
        _ = store
      }

      XCTAssertEqual(
        Logger.shared.logs,
        [
          "Store<(), ()>.init",
          "Store<(), ()>.deinit",
        ]
      )
      await self.fulfillment(of: [effectFinished], timeout: 0.5)
    }

    @MainActor
    func testStoreDeinit_RunningCombineEffect() async {
      Logger.shared.isEnabled = true
      let effectFinished = self.expectation(description: "Effect finished")
      do {
        let store = Store<Void, Void>(initialState: ()) {
          Reduce { state, _ in
            .publisher {
              Empty(completeImmediately: false)
                .handleEvents(receiveCancel: {
                  effectFinished.fulfill()
                })
            }
          }
        }
        store.send(())
        _ = store
      }

      XCTAssertEqual(
        Logger.shared.logs,
        [
          "Store<(), ()>.init",
          "Store<(), ()>.deinit",
        ]
      )
      await self.fulfillment(of: [effectFinished], timeout: 0.5)
    }
  #endif

  @MainActor
  @available(*, deprecated)
  func testUnCachedStores() async {
    Logger.shared.isEnabled = true
    let clock = TestClock()
    let store = Store(initialState: Parent.State()) {
      Parent()
    } withDependencies: {
      $0.continuousClock = clock
    }
    do {
      let child = store.scope(state: { $0.child }, action: { .child($0) })
      child.send(.start)
      XCTAssertEqual(store.withState(\.child.count), 1)
    }
    await clock.run()
    XCTAssertEqual(store.withState(\.child.count), 2)
  }
}

@Reducer
@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
private struct Child {
  struct State: Equatable {
    var count = 0
  }
  enum Action {
    case tap
    case start
    case response
  }
  @Dependency(\.continuousClock) var clock
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .tap:
        state.count += 1
        return .none
      case .start:
        state.count += 1
        return .run { send in
          try await clock.sleep(for: .seconds(0))
          await send(.response)
        }
      case .response:
        state.count += 1
        return .none
      }
    }
  }
}

@Reducer
@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
private struct Parent {
  struct State: Equatable {
    var child = Child.State()
  }
  enum Action {
    case child(Child.Action)
  }
  var body: some ReducerOf<Self> {
    Scope(state: \.child, action: \.child) {
      Child()
    }
  }
}

@Reducer
@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
private struct Grandparent {
  struct State: Equatable {
    var child = Parent.State()
  }
  enum Action {
    case child(Parent.Action)
    case incrementGrandchild
  }
  var body: some ReducerOf<Self> {
    Scope(state: \.child, action: \.child) {
      Parent()
    }
    Reduce { state, action in
      switch action {
      case .child:
        return .none
      case .incrementGrandchild:
        state.child.child.count += 1
        return .none
      }
    }
  }
}
