import Combine
import ComposableArchitecture
import XCTest

@MainActor
final class ObservableTests: BaseTCATestCase {
  func testBasics() async {
    var state = ChildState()
    let countDidChange = self.expectation(description: "count.didChange")

    withPerceptionTracking {
      _ = state.count
    } onChange: {
      countDidChange.fulfill()
    }

    state.count += 1
    await self.fulfillment(of: [countDidChange], timeout: 0)
  }

  func testChildCountMutation() async {
    var state = ParentState()
    let childCountDidChange = self.expectation(description: "child.count.didChange")

    withPerceptionTracking {
      _ = state.child.count
    } onChange: {
      childCountDidChange.fulfill()
    }
    withPerceptionTracking {
      _ = state.child
    } onChange: {
      XCTFail("state.child should not change.")
    }

    state.child.count += 1
    await self.fulfillment(of: [childCountDidChange], timeout: 0)
  }

  func testChildReset() async {
    var state = ParentState()
    let childDidChange = self.expectation(description: "child.didChange")

    withPerceptionTracking {
      _ = state.child
    } onChange: {
      childDidChange.fulfill()
    }

    state.child = ChildState()
    await self.fulfillment(of: [childDidChange], timeout: 0)
  }

  func testReplaceChild() async {
    var state = ParentState()
    let childDidChange = self.expectation(description: "child.didChange")

    withPerceptionTracking {
      _ = state.child
    } onChange: {
      childDidChange.fulfill()
    }

    state.child.replace(with: ChildState(count: 42))
    await self.fulfillment(of: [childDidChange], timeout: 0)
    XCTAssertEqual(state.child.count, 42) // todo: do this for all tests
  }

  func testResetChild() async {
    var state = ParentState()
    let childDidChange = self.expectation(description: "child.didChange")

    withPerceptionTracking {
      _ = state.child
    } onChange: {
      childDidChange.fulfill()
    }

    state.child.reset()
    await self.fulfillment(of: [childDidChange], timeout: 0)
  }

  func testReplaceChild_Store() async {
    let store = Store<ParentState, Void>(initialState: ParentState()) {
      Reduce { state, _ in
        state.child.replace(with: ChildState())
        return .none
      }
    }
    let childDidChange = self.expectation(description: "child.didChange")

    withPerceptionTracking {
      _ = store.child
    } onChange: {
      childDidChange.fulfill()
    }

    store.send(())
    await self.fulfillment(of: [childDidChange], timeout: 0)
  }

  func testResetChild_Store() async {
    let store = Store<ParentState, Void>(initialState: ParentState()) {
      Reduce { state, _ in
        state.child.reset()
        return .none
      }
    }
    let childDidChange = self.expectation(description: "child.didChange")

    withPerceptionTracking {
      _ = store.child
    } onChange: {
      childDidChange.fulfill()
    }

    store.send(())
    await self.fulfillment(of: [childDidChange], timeout: 0)
  }
}

@ObservableState
private struct ChildState {
  var count = 0
  mutating func replace(with other: Self) {
    self = other
  }
  mutating func reset() {
    self = Self()
  }
}
@ObservableState
private struct ParentState {
  var child = ChildState()
}
