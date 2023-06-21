import ComposableArchitecture
@_spi(Concurrency) import Dependencies
import XCTest

@MainActor
final class SynchronizedStateReducerTests: BaseTCATestCase {

  func testChildrenStateUpdateChangesParent() {
    struct SingleChildReducer: ReducerProtocol {
      typealias State = Parent
      typealias Action = Void

      var body: some ReducerProtocol<State, Action> {
        Reduce { state, _ in
          state.child.foo += 1
          return .none
        }
        .synchronizeState(
          over: .init(
            parent: .synchronize(\Parent.foo),
            children: [
              .synchronize(\Parent.child.foo)
            ]
          )
        )
      }
    }

    let reducer = SingleChildReducer()
    var state = Parent(
      foo: 0,
      child: .init(foo: 0)
    )
    _ = reducer.reduce(into: &state, action: ())
    XCTAssertEqual(1, state.foo)
    XCTAssertEqual(1, state.child.foo)
  }

  func testParentStateUpdateChangesChildrenState() {
    struct MultiChildReducer: ReducerProtocol {
      typealias State = ParentMultiChild
      typealias Action = Void

      var body: some ReducerProtocol<State, Action> {
        Reduce { state, _ in
          state.foo += 1
          return .none
        }
        .synchronizeState(
          over: .init(
            parent: .synchronize(\ParentMultiChild.foo),
            children: [
              .synchronize(\ParentMultiChild.child1.foo),
              .synchronize(\ParentMultiChild.child2.foo),
              .synchronize(\ParentMultiChild.child3.foo),
            ]
          )
        )
      }
    }

    let reducer = MultiChildReducer()
    var state = ParentMultiChild(
      foo: 0,
      child1: .init(foo: 0),
      child2: .init(foo: 0),
      child3: .init(foo: 0)
    )

    _ = reducer.reduce(into: &state, action: ())
    XCTAssertEqual(1, state.foo)
    XCTAssertEqual(1, state.child1.foo)
    XCTAssertEqual(1, state.child2.foo)
    XCTAssertEqual(1, state.child3.foo)
  }

  func testWriteOnlyParentStateChangeDoesNotUpdateChild() {
    struct SingleChildReducer: ReducerProtocol {
      typealias State = Parent
      typealias Action = Void

      var body: some ReducerProtocol<State, Action> {
        Reduce { state, _ in
          state.foo += 1
          return .none
        }
        .synchronizeState(
          over: .init(
            parent: .updateOnly(\Parent.foo),
            children: [
              .synchronize(\Parent.child.foo)
            ]
          )
        )
      }
    }

    let reducer = SingleChildReducer()
    var state = Parent(
      foo: 0,
      child: .init(foo: 0)
    )
    _ = reducer.reduce(into: &state, action: ())
    XCTAssertEqual(1, state.foo)
    XCTAssertEqual(0, state.child.foo)
  }

  func testParentStateChangeDoesNotUpdateReadOnlyChild() {
    struct SingleChildReducer: ReducerProtocol {
      typealias State = Parent
      typealias Action = Void

      var body: some ReducerProtocol<State, Action> {
        Reduce { state, _ in
          state.foo += 1
          return .none
        }
        .synchronizeState(
          over: .init(
            parent: .synchronize(\Parent.foo),
            children: [
              .observeOnly(\Parent.child.foo)
            ]
          )
        )
      }
    }

    let reducer = SingleChildReducer()
    var state = Parent(
      foo: 0,
      child: .init(foo: 0)
    )
    _ = reducer.reduce(into: &state, action: ())
    XCTAssertEqual(1, state.foo)
    XCTAssertEqual(0, state.child.foo)
  }

  func testReadOnlyParentWithReadWriteChild() {
    struct SingleChildReducer: ReducerProtocol {
      typealias State = Parent
      typealias Action = ParentAction

      var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
          switch action {
          case .updateChild:
            state.child.foo += 1
          case .updateParent:
            state.foo += 2
          }
          return .none
        }
        .synchronizeState(
          over: .init(
            parent: .updateOnly(\Parent.foo),
            children: [
              .synchronize(\Parent.child.foo)
            ]
          )
        )
      }
    }

    let reducer = SingleChildReducer()
    var state = Parent(
      foo: 0,
      child: .init(foo: 0)
    )
    // Update parent and nothing changes on child.
    _ = reducer.reduce(into: &state, action: .updateParent)
    XCTAssertEqual(2, state.foo)
    XCTAssertEqual(0, state.child.foo)

    // Update child and it changes on parent too.
    _ = reducer.reduce(into: &state, action: .updateChild)
    XCTAssertEqual(1, state.foo)
    XCTAssertEqual(1, state.child.foo)
  }

  func testParentWithReadOnlyChild() {
    struct SingleChildReducer: ReducerProtocol {
      typealias State = Parent
      typealias Action = ParentAction

      var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
          switch action {
          case .updateChild:
            state.child.foo += 1
          case .updateParent:
            state.foo += 2
          }
          return .none
        }
        .synchronizeState(
          over: .init(
            parent: .synchronize(\Parent.foo),
            children: [
              .observeOnly(\Parent.child.foo)
            ]
          )
        )
      }
    }

    let reducer = SingleChildReducer()
    var state = Parent(
      foo: 0,
      child: .init(foo: 0)
    )

    // Update parent and nothing changes on child.
    _ = reducer.reduce(into: &state, action: .updateParent)
    XCTAssertEqual(2, state.foo)
    XCTAssertEqual(0, state.child.foo)

    // Update child and parent changes too.
    _ = reducer.reduce(into: &state, action: .updateChild)
    XCTAssertEqual(1, state.foo)
    XCTAssertEqual(1, state.child.foo)
  }

  func testMultiChildComboWithReadWriteParent() {
    struct MultiChildReducer: ReducerProtocol {
      typealias State = ParentMultiChild
      typealias Action = ParentMultiChildAction

      var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
          switch action {
          case .updateChild1:
            state.child1.foo += 1
          case .updateChild2:
            state.child2.foo += 2
          case .updateChild3:
            state.child3.foo += 3
          case .updateParent:
            state.foo += 20
          }
          return .none
        }
        .synchronizeState(
          over: .init(
            parent: .synchronize(\ParentMultiChild.foo),
            children: [
              .observeOnly(\ParentMultiChild.child1.foo),
              .synchronize(\ParentMultiChild.child2.foo),
              .updateOnly(\ParentMultiChild.child3.foo),
            ]
          )
        )
      }
    }

    let reducer = MultiChildReducer()
    var state = ParentMultiChild(
      foo: 0,
      child1: .init(foo: 0),
      child2: .init(foo: 0),
      child3: .init(foo: 0)
    )

    // Update parent and child 2 and child 3 get updated..
    _ = reducer.reduce(into: &state, action: .updateParent)
    XCTAssertEqual(20, state.foo)
    XCTAssertEqual(0, state.child1.foo)
    XCTAssertEqual(20, state.child2.foo)
    XCTAssertEqual(20, state.child3.foo)

    // Update child 3 and nothing changes with others, since it is not tracked for changes.
    _ = reducer.reduce(into: &state, action: .updateChild3)
    XCTAssertEqual(20, state.foo)
    XCTAssertEqual(0, state.child1.foo)
    XCTAssertEqual(20, state.child2.foo)
    XCTAssertEqual(23, state.child3.foo)

    // Update child 1 and other writable ones change.
    _ = reducer.reduce(into: &state, action: .updateChild1)
    XCTAssertEqual(1, state.foo)
    XCTAssertEqual(1, state.child1.foo)
    XCTAssertEqual(1, state.child2.foo)
    XCTAssertEqual(1, state.child3.foo)
  }

  func testMultiChildComboWithReadOnlyParent() {
    struct MultiChildReducer: ReducerProtocol {
      typealias State = ParentMultiChild
      typealias Action = ParentMultiChildAction

      var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
          switch action {
          case .updateChild1:
            state.child1.foo += 1
          case .updateChild2:
            state.child2.foo += 2
          case .updateChild3:
            state.child3.foo += 3
          case .updateParent:
            state.foo += 20
          }
          return .none
        }
        .synchronizeState(
          over: .init(
            parent: .observeOnly(\ParentMultiChild.foo),
            children: [
              .observeOnly(\ParentMultiChild.child1.foo),
              .synchronize(\ParentMultiChild.child2.foo),
              .updateOnly(\ParentMultiChild.child3.foo),
            ]
          )
        )
      }
    }

    let reducer = MultiChildReducer()
    var state = ParentMultiChild(
      foo: 0,
      child1: .init(foo: 0),
      child2: .init(foo: 0),
      child3: .init(foo: 0)
    )

    // Update parent and child 2 and child 3 get updated..
    _ = reducer.reduce(into: &state, action: .updateParent)
    XCTAssertEqual(20, state.foo)
    XCTAssertEqual(0, state.child1.foo)
    XCTAssertEqual(20, state.child2.foo)
    XCTAssertEqual(20, state.child3.foo)

    // Update child 3 and nothing changes with others, since it is not tracked for changes.
    _ = reducer.reduce(into: &state, action: .updateChild3)
    XCTAssertEqual(20, state.foo)
    XCTAssertEqual(0, state.child1.foo)
    XCTAssertEqual(20, state.child2.foo)
    XCTAssertEqual(23, state.child3.foo)

    // Update child 1 and other writable ones change.
    _ = reducer.reduce(into: &state, action: .updateChild1)
    XCTAssertEqual(20, state.foo)  // Parent is read only.
    XCTAssertEqual(1, state.child1.foo)
    XCTAssertEqual(1, state.child2.foo)
    XCTAssertEqual(1, state.child3.foo)
  }

  func testMultiChildComboWithWriteOnlyParent() {
    struct MultiChildReducer: ReducerProtocol {
      typealias State = ParentMultiChild
      typealias Action = ParentMultiChildAction

      var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
          switch action {
          case .updateChild1:
            state.child1.foo += 1
          case .updateChild2:
            state.child2.foo += 2
          case .updateChild3:
            state.child3.foo += 3
          case .updateParent:
            state.foo += 20
          }
          return .none
        }
        .synchronizeState(
          over: .init(
            parent: .updateOnly(\ParentMultiChild.foo),
            children: [
              .observeOnly(\ParentMultiChild.child1.foo),
              .synchronize(\ParentMultiChild.child2.foo),
              .updateOnly(\ParentMultiChild.child3.foo),
            ]
          )
        )
      }
    }

    let reducer = MultiChildReducer()
    var state = ParentMultiChild(
      foo: 0,
      child1: .init(foo: 0),
      child2: .init(foo: 0),
      child3: .init(foo: 0)
    )

    // Update parent and nothing else changes becuase parent is write only.
    _ = reducer.reduce(into: &state, action: .updateParent)
    XCTAssertEqual(20, state.foo)
    XCTAssertEqual(0, state.child1.foo)
    XCTAssertEqual(0, state.child2.foo)
    XCTAssertEqual(0, state.child3.foo)

    // Update child 3 and nothing changes with others, since it is not tracked for changes.
    _ = reducer.reduce(into: &state, action: .updateChild3)
    XCTAssertEqual(20, state.foo)
    XCTAssertEqual(0, state.child1.foo)
    XCTAssertEqual(0, state.child2.foo)
    XCTAssertEqual(3, state.child3.foo)

    // Update child 1 and other writable ones change.
    _ = reducer.reduce(into: &state, action: .updateChild1)
    XCTAssertEqual(1, state.foo)  // Parent is write only.
    XCTAssertEqual(1, state.child1.foo)
    XCTAssertEqual(1, state.child2.foo)
    XCTAssertEqual(1, state.child3.foo)
  }
}

struct Parent: Equatable {
  var foo: Int
  var child: Child
}

enum ParentAction: Equatable {
  case updateParent
  case updateChild
}

enum ParentMultiChildAction: Equatable {
  case updateParent
  case updateChild1
  case updateChild2
  case updateChild3
}

struct ParentMultiChild: Equatable {
  var foo: Int
  var child1: Child
  var child2: Child
  var child3: Child
}

struct Child: Equatable {
  var foo: Int
}
