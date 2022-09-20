import ComposableArchitecture
import XCTest

@testable import Todos

@MainActor
final class TodosTests: XCTestCase {
  let mainQueue = DispatchQueue.test

  func testAddTodo() async {
    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: self.mainQueue.eraseToAnyScheduler(),
        uuid: UUID.incrementing
      )
    )

    await store.send(.addTodoButtonTapped) {
      $0.todos.insert(
        TodoState(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        ),
        at: 0
      )
    }

    await store.send(.addTodoButtonTapped) {
      $0.todos = [
        TodoState(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          isComplete: false
        ),
        TodoState(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        ),
      ]
    }
  }

  func testEditTodo() async {
    let state = AppState(
      todos: [
        TodoState(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        )
      ]
    )
    let store = TestStore(
      initialState: state,
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: self.mainQueue.eraseToAnyScheduler(),
        uuid: UUID.incrementing
      )
    )

    await store.send(
      .todo(id: state.todos[0].id, action: .textFieldChanged("Learn Composable Architecture"))
    ) {
      $0.todos[id: state.todos[0].id]?.description = "Learn Composable Architecture"
    }
  }

  func testCompleteTodo() async {
    let state = AppState(
      todos: [
        TodoState(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        ),
        TodoState(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          isComplete: false
        ),
      ]
    )
    let store = TestStore(
      initialState: state,
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: self.mainQueue.eraseToAnyScheduler(),
        uuid: UUID.incrementing
      )
    )

    await store.send(.todo(id: state.todos[0].id, action: .checkBoxToggled)) {
      $0.todos[id: state.todos[0].id]?.isComplete = true
    }
    await self.mainQueue.advance(by: 1)
    await store.receive(.sortCompletedTodos) {
      $0.todos = [
        $0.todos[1],
        $0.todos[0],
      ]
    }
  }

  func testCompleteTodoDebounces() async {
    let state = AppState(
      todos: [
        TodoState(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        ),
        TodoState(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          isComplete: false
        ),
      ]
    )
    let store = TestStore(
      initialState: state,
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: self.mainQueue.eraseToAnyScheduler(),
        uuid: UUID.incrementing
      )
    )

    await store.send(.todo(id: state.todos[0].id, action: .checkBoxToggled)) {
      $0.todos[id: state.todos[0].id]?.isComplete = true
    }
    await self.mainQueue.advance(by: 0.5)
    await store.send(.todo(id: state.todos[0].id, action: .checkBoxToggled)) {
      $0.todos[id: state.todos[0].id]?.isComplete = false
    }
    await self.mainQueue.advance(by: 1)
    await store.receive(.sortCompletedTodos)
  }

  func testClearCompleted() async {
    let state = AppState(
      todos: [
        TodoState(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        ),
        TodoState(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          isComplete: true
        ),
      ]
    )
    let store = TestStore(
      initialState: state,
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: self.mainQueue.eraseToAnyScheduler(),
        uuid: UUID.incrementing
      )
    )

    await store.send(.clearCompletedButtonTapped) {
      $0.todos = [
        $0.todos[0]
      ]
    }
  }

  func testDelete() async {
    let state = AppState(
      todos: [
        TodoState(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        ),
        TodoState(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          isComplete: false
        ),
        TodoState(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
          isComplete: false
        ),
      ]
    )
    let store = TestStore(
      initialState: state,
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: self.mainQueue.eraseToAnyScheduler(),
        uuid: UUID.incrementing
      )
    )

    await store.send(.delete([1])) {
      $0.todos = [
        $0.todos[0],
        $0.todos[2],
      ]
    }
  }

  func testEditModeMoving() async {
    let state = AppState(
      todos: [
        TodoState(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        ),
        TodoState(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          isComplete: false
        ),
        TodoState(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
          isComplete: false
        ),
      ]
    )
    let store = TestStore(
      initialState: state,
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: self.mainQueue.eraseToAnyScheduler(),
        uuid: UUID.incrementing
      )
    )

    await store.send(.editModeChanged(.active)) {
      $0.editMode = .active
    }
    await store.send(.move([0], 2)) {
      $0.todos = [
        $0.todos[1],
        $0.todos[0],
        $0.todos[2],
      ]
    }
    await self.mainQueue.advance(by: .milliseconds(100))
    await store.receive(.sortCompletedTodos)
  }

  func testEditModeMovingWithFilter() async {
    let state = AppState(
      todos: [
        TodoState(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        ),
        TodoState(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          isComplete: false
        ),
        TodoState(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
          isComplete: true
        ),
        TodoState(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
          isComplete: true
        ),
      ]
    )
    let store = TestStore(
      initialState: state,
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: self.mainQueue.eraseToAnyScheduler(),
        uuid: UUID.incrementing
      )
    )

    await store.send(.editModeChanged(.active)) {
      $0.editMode = .active
    }
    await store.send(.filterPicked(.completed)) {
      $0.filter = .completed
    }
    await store.send(.move([0], 2)) {
      $0.todos = [
        $0.todos[0],
        $0.todos[1],
        $0.todos[3],
        $0.todos[2],
      ]
    }
    await self.mainQueue.advance(by: .milliseconds(100))
    await store.receive(.sortCompletedTodos)
  }

  func testFilteredEdit() async {
    let state = AppState(
      todos: [
        TodoState(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        ),
        TodoState(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          isComplete: true
        ),
      ]
    )
    let store = TestStore(
      initialState: state,
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: self.mainQueue.eraseToAnyScheduler(),
        uuid: UUID.incrementing
      )
    )

    await store.send(.filterPicked(.completed)) {
      $0.filter = .completed
    }
    await store.send(.todo(id: state.todos[1].id, action: .textFieldChanged("Did this already"))) {
      $0.todos[id: state.todos[1].id]?.description = "Did this already"
    }
  }
}

extension UUID {
  // A deterministic, auto-incrementing "UUID" generator for testing.
  static var incrementing: @Sendable () -> UUID {
    class UncheckedCount: @unchecked Sendable {
      var value = 0
      func increment() { self.value += 1 }
    }
    let count = UncheckedCount()
    return {
      defer { count.increment() }
      return UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012x", count.value))")!
    }
  }
}
