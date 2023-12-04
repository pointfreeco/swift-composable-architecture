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
    XCTAssertEqual(state.count, 1)
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
    XCTAssertEqual(state.child.count, 1)
  }

  func testChildReset() async {
    var state = ParentState()
    let childDidChange = self.expectation(description: "child.didChange")

    var child = state.child
    withPerceptionTracking {
      _ = child.count
    } onChange: {
      XCTFail("child.count should not change.")
    }
    withPerceptionTracking {
      _ = state.child
    } onChange: {
      childDidChange.fulfill()
    }

    state.child = ChildState(count: 42)
    await self.fulfillment(of: [childDidChange], timeout: 0)
    XCTAssertEqual(state.child.count, 42)
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
    XCTAssertEqual(state.child.count, 42)
  }

  func testResetChild() async {
    var state = ParentState(child: ChildState(count: 42))
    let childDidChange = self.expectation(description: "child.didChange")

    withPerceptionTracking {
      _ = state.child
    } onChange: {
      childDidChange.fulfill()
    }

    state.child.reset()
    await self.fulfillment(of: [childDidChange], timeout: 0)
    XCTAssertEqual(state.child.count, 0)
  }

  func testSwapSiblings() async {
    var state = ParentState(
      child: ChildState(count: 1),
      sibling: ChildState(count: -1)
    )
    let childDidChange = self.expectation(description: "child.didChange")
    let siblingDidChange = self.expectation(description: "sibling.didChange")

    withPerceptionTracking {
      _ = state.child
    } onChange: {
      childDidChange.fulfill()
    }
    withPerceptionTracking {
      _ = state.sibling
    } onChange: {
      siblingDidChange.fulfill()
    }

    state.swap()
    await self.fulfillment(of: [childDidChange], timeout: 0)
    await self.fulfillment(of: [siblingDidChange], timeout: 0)
    XCTAssertEqual(state.child.count, -1)
    XCTAssertEqual(state.sibling.count, 1)
  }

  func testPresentOptional() async {
    var state = ParentState()
    let optionalDidChange = self.expectation(description: "optional.didChange")

    withPerceptionTracking {
      _ = state.optional
    } onChange: {
      optionalDidChange.fulfill()
    }

    state.optional = ChildState(count: 42)
    await self.fulfillment(of: [optionalDidChange], timeout: 0)
    XCTAssertEqual(state.optional?.count, 42)
  }

  func testMutatePresentedOptional() async {
    var state = ParentState(optional: ChildState())
    let optionalCountDidChange = self.expectation(description: "optional.count.didChange")

    withPerceptionTracking {
      _ = state.optional
    } onChange: {
      XCTFail("Optional should not change")
    }
    let optional = state.optional
    withPerceptionTracking {
      _ = optional?.count
    } onChange: {
      optionalCountDidChange.fulfill()
    }

    state.optional?.count += 1
    await self.fulfillment(of: [optionalCountDidChange], timeout: 0)
    XCTAssertEqual(state.optional?.count, 1)
  }

  func testPresentDestination() async {
    var state = ParentState()
    let destinationDidChange = self.expectation(description: "destination.didChange")

    withPerceptionTracking {
      _ = state.destination
    } onChange: {
      destinationDidChange.fulfill()
    }

    state.destination = .child1(ChildState(count: 42))
    await self.fulfillment(of: [destinationDidChange], timeout: 0)
    XCTAssertEqual(state.destination?[case: \.child1]?.count, 42)
  }

  func testDismissDestination() async {
    var state = ParentState(destination: .child1(ChildState()))
    let destinationDidChange = self.expectation(description: "destination.didChange")

    withPerceptionTracking {
      _ = state.destination
    } onChange: {
      destinationDidChange.fulfill()
    }

    state.destination = nil
    await self.fulfillment(of: [destinationDidChange], timeout: 0)
    XCTAssertEqual(state.destination, nil)
  }

  func testChangeDestination() async {
    var state = ParentState(destination: .child1(ChildState()))
    let destinationDidChange = self.expectation(description: "destination.didChange")

    withPerceptionTracking {
      _ = state.destination
    } onChange: {
      destinationDidChange.fulfill()
    }

    state.destination = .child2(ChildState(count: 42))
    await self.fulfillment(of: [destinationDidChange], timeout: 0)
    XCTAssertEqual(state.destination?[case: \.child2]?.count, 42)
  }

  func testChangeDestination_KeepIdentity() async {
    let childState = ChildState(count: 42)
    var state = ParentState(destination: .child1(childState))
    let destinationDidChange = self.expectation(description: "destination.didChange")

    withPerceptionTracking {
      _ = state.destination
    } onChange: {
      destinationDidChange.fulfill()
    }

    state.destination = .child2(childState)
    await self.fulfillment(of: [destinationDidChange], timeout: 0)
    XCTAssertEqual(state.destination?[case: \.child2]?.count, 42)
  }

  func testReplaceChild_Store() async {
    let store = Store<ParentState, Void>(initialState: ParentState()) {
      Reduce { state, _ in
        state.child.replace(with: ChildState(count: 42))
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
    XCTAssertEqual(store.child.count, 42)
  }

  func testResetChild_Store() async {
    let store = Store<ParentState, Void>(initialState: ParentState(child: ChildState(count: 42))) {
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
    XCTAssertEqual(store.child.count, 0)
  }
}

@ObservableState
private struct ChildState: Equatable {
  var count = 0
  mutating func replace(with other: Self) {
    self = other
  }
  mutating func reset() {
    self = Self()
  }
}
@ObservableState
private struct ParentState: Equatable {
  var child = ChildState()
  @Presents var destination: DestinationState?
  @Presents var optional: ChildState?
  var sibling = ChildState()
  mutating func swap() {
    var childCopy = child
    self.child = self.sibling
    self.sibling = childCopy
  }
}
@CasePathable
@ObservableState
private enum DestinationState: Equatable {
  case child1(ChildState)
  case child2(ChildState)
}
