import Combine
import ComposableArchitecture
import XCTest

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

  func testReplace() async {
    XCTTODO("Ideally this would pass but we cannot detect this kind of mutation currently.")

    var state = ChildState(count: 42)
    let countDidChange = self.expectation(description: "count.didChange")

    withPerceptionTracking {
      _ = state.count
    } onChange: {
      countDidChange.fulfill()
    }

    state.replace(with: ChildState())
    await self.fulfillment(of: [countDidChange], timeout: 0)
    XCTAssertEqual(state.count, 0)
  }

  func testReset() async {
    XCTTODO("Ideally this would pass but we cannot detect this kind of mutation currently.")

    var state = ChildState(count: 42)
    let countDidChange = self.expectation(description: "count.didChange")

    withPerceptionTracking {
      _ = state.count
    } onChange: {
      countDidChange.fulfill()
    }

    state.reset()
    await self.fulfillment(of: [countDidChange], timeout: 0)
    XCTAssertEqual(state.count, 0)
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

    let child = state.child
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
    XCTAssertEqual(state.destination?.child1?.count, 42)
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
    XCTAssertEqual(state.destination?.child2?.count, 42)
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
    XCTAssertEqual(state.destination?.child2?.count, 42)
  }

  func testMutatingDestination_NonObservableCase() async {
    let expectation = self.expectation(description: "destination.didChange")
    var state = ParentState(destination: .inert(0))

    withPerceptionTracking {
      _ = state.destination
    } onChange: {
      expectation.fulfill()
    }

    state.destination = .inert(1)
    XCTAssertEqual(state.destination, .inert(1))
    await self.fulfillment(of: [expectation])
  }

  func testReplaceWithCopy() async {
    let childState = ChildState(count: 1)
    var childStateCopy = childState
    childStateCopy.count = 2
    var state = ParentState(child: childState, sibling: childStateCopy)
    let childCountDidChange = self.expectation(description: "child.count.didChange")

    withPerceptionTracking {
      _ = state.child.count
    } onChange: {
      childCountDidChange.fulfill()
    }

    state.child.replace(with: state.sibling)

    await self.fulfillment(of: [childCountDidChange], timeout: 0)
    XCTAssertEqual(state.child.count, 2)
    XCTAssertEqual(state.sibling.count, 2)
  }

  @MainActor
  func testStore_ReplaceChild() async {
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

  @MainActor
  func testStore_Replace() async {
    let store = Store<ChildState, Void>(initialState: ChildState()) {
      Reduce { state, _ in
        state.replace(with: ChildState(count: 42))
        return .none
      }
    }
    let countDidChange = self.expectation(description: "child.didChange")

    withPerceptionTracking {
      _ = store.count
    } onChange: {
      countDidChange.fulfill()
    }

    store.send(())
    await self.fulfillment(of: [countDidChange], timeout: 0)
    XCTAssertEqual(store.count, 42)
  }

  @MainActor
  func testStore_ResetChild() async {
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

  @MainActor
  func testStore_Reset() async {
    let store = Store<ChildState, Void>(initialState: ChildState(count: 42)) {
      Reduce { state, _ in
        state.reset()
        return .none
      }
    }
    let countDidChange = self.expectation(description: "child.didChange")

    withPerceptionTracking {
      _ = store.count
    } onChange: {
      countDidChange.fulfill()
    }

    store.send(())
    await self.fulfillment(of: [countDidChange], timeout: 0)
    XCTAssertEqual(store.count, 0)
  }

  func testIdentifiedArray_AddElement() {
    var state = ParentState()
    let rowsDidChange = self.expectation(description: "rowsDidChange")

    withPerceptionTracking {
      _ = state.rows
    } onChange: {
      rowsDidChange.fulfill()
    }

    state.rows.append(ChildState())
    XCTAssertEqual(state.rows.count, 1)
    self.wait(for: [rowsDidChange], timeout: 0)
  }

  func testIdentifiedArray_MutateElement() {
    var state = ParentState(rows: [
      ChildState(),
      ChildState(),
    ])
    let firstRowCountDidChange = self.expectation(description: "firstRowCountDidChange")

    withPerceptionTracking {
      _ = state.rows
    } onChange: {
      XCTFail("rows should not change")
    }
    withPerceptionTracking {
      _ = state.rows[0]
    } onChange: {
      XCTFail("rows[0] should not change")
    }
    withPerceptionTracking {
      _ = state.rows[0].count
    } onChange: {
      firstRowCountDidChange.fulfill()
    }
    withPerceptionTracking {
      _ = state.rows[1].count
    } onChange: {
      XCTFail("rows[1].count should not change")
    }

    state.rows[0].count += 1
    XCTAssertEqual(state.rows[0].count, 1)
    self.wait(for: [firstRowCountDidChange], timeout: 0)
  }

  func testPresents_NilToNonNil() {
    var state = ParentState()
    let presentationDidChange = self.expectation(description: "presentationDidChange")

    withPerceptionTracking {
      _ = state.presentation
    } onChange: {
      presentationDidChange.fulfill()
    }

    state.presentation = ChildState()
    XCTAssertEqual(state.presentation?.count, 0)
    self.wait(for: [presentationDidChange], timeout: 0)
  }

  func testPresents_Mutate() {
    var state = ParentState(presentation: ChildState())
    let presentationCountDidChange = self.expectation(description: "presentationCountDidChange")

    withPerceptionTracking {
      _ = state.presentation
    } onChange: {
      XCTFail("presentation should not change")
    }
    withPerceptionTracking {
      _ = state.presentation?.count
    } onChange: {
      presentationCountDidChange.fulfill()
    }

    state.presentation?.count += 1
    XCTAssertEqual(state.presentation?.count, 1)
    self.wait(for: [presentationCountDidChange], timeout: 0)
  }

  func testStackState_AddElement() {
    var state = ParentState()
    let pathDidChange = self.expectation(description: "pathDidChange")

    withPerceptionTracking {
      _ = state.path
    } onChange: {
      pathDidChange.fulfill()
    }

    state.path.append(ChildState())
    XCTAssertEqual(state.path.count, 1)
    self.wait(for: [pathDidChange], timeout: 0)
  }

  func testStackState_MutateElement() {
    var state = ParentState(
      path: StackState([
        ChildState(),
        ChildState(),
      ])
    )
    let firstElementCountDidChange = self.expectation(description: "firstElementCountDidChange")

    withPerceptionTracking {
      _ = state.path
    } onChange: {
      XCTFail("path should not change")
    }
    withPerceptionTracking {
      _ = state.path[0]
    } onChange: {
      XCTFail("path[0] should not change")
    }
    withPerceptionTracking {
      _ = state.path[0].count
    } onChange: {
      firstElementCountDidChange.fulfill()
    }
    withPerceptionTracking {
      _ = state.path[1].count
    } onChange: {
      XCTFail("path[1].count should not change")
    }

    state.path[id: 0]?.count += 1
    XCTAssertEqual(state.path[0].count, 1)
    self.wait(for: [firstElementCountDidChange], timeout: 0)
  }

  func testCopy() {
    var state = ParentState()
    var childCopy = state.child.copy()
    childCopy.count = 42
    let childCountDidChange = self.expectation(description: "childCountDidChange")

    withPerceptionTracking {
      _ = state.child.count
    } onChange: {
      childCountDidChange.fulfill()
    }

    state.child.replace(with: childCopy)
    XCTAssertEqual(state.child.count, 42)
    self.wait(for: [childCountDidChange], timeout: 0)
  }

  func testArrayAppend() {
    var state = ParentState()
    let childrenDidChange = self.expectation(description: "childrenDidChange")

    withPerceptionTracking {
      _ = state.children
    } onChange: {
      childrenDidChange.fulfill()
    }

    state.children.append(ChildState())
    self.wait(for: [childrenDidChange])
  }

  func testArrayMutate() {
    var state = ParentState(children: [ChildState()])

    withPerceptionTracking {
      _ = state.children
    } onChange: {
      XCTFail("children should not change")
    }

    state.children[0].count += 1
  }

  func testEnumStateWithInertCases() {
    let store = Store<EnumState, Void>(initialState: EnumState.count(.one)) {
      Reduce { state, _ in
        state = .count(.two)
        return .none
      }
    }
    let onChangeExpectation = self.expectation(description: "onChange")
    withPerceptionTracking {
      _ = store.state
    } onChange: {
      onChangeExpectation.fulfill()
    }

    store.send(())

    self.wait(for: [onChangeExpectation], timeout: 0)
  }

  func testEnumStateWithInertCasesTricky() {
    let store = Store<EnumState, Void>(initialState: EnumState.count(.one)) {
      Reduce { state, _ in
        state = .anotherCount(.one)
        return .none
      }
    }
    let onChangeExpectation = self.expectation(description: "onChange")
    withPerceptionTracking {
      _ = store.state
    } onChange: {
      onChangeExpectation.fulfill()
    }

    store.send(())

    self.wait(for: [onChangeExpectation], timeout: 0)
  }

  func testEnumStateWithIntCase() {
    let store = Store<EnumState, Void>(initialState: EnumState.int(0)) {
      Reduce { state, _ in
        state = .int(1)
        return .none
      }
    }
    let onChangeExpectation = self.expectation(description: "onChange")
    withPerceptionTracking {
      _ = store.state
    } onChange: {
      onChangeExpectation.fulfill()
    }

    store.send(())

    self.wait(for: [onChangeExpectation], timeout: 0)
  }
}

@ObservableState
private struct ChildState: Equatable, Identifiable {
  let id = UUID()
  var count = 0
  mutating func replace(with other: Self) {
    self = other
  }
  mutating func reset() {
    self = Self()
  }
  mutating func copy() -> Self {
    self
  }
}
@ObservableState
private struct ParentState: Equatable {
  var child = ChildState()
  @Presents var destination: DestinationState?
  var children: [ChildState] = []
  @Presents var optional: ChildState?
  var path = StackState<ChildState>()
  @Presents var presentation: ChildState?
  var rows: IdentifiedArrayOf<ChildState> = []
  var sibling = ChildState()
  mutating func swap() {
    let childCopy = child
    self.child = self.sibling
    self.sibling = childCopy
  }
}
@dynamicMemberLookup
@CasePathable
@ObservableState
private enum DestinationState: Equatable {
  case child1(ChildState)
  case child2(ChildState)
  case inert(Int)
}
@ObservableState
private enum EnumState: Equatable {
  case count(Count)
  case anotherCount(Count)
  case int(Int)
  @ObservableState
  enum Count: String {
    case one, two
  }
}
