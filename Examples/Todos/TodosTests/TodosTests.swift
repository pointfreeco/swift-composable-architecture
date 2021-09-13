import ComposableArchitecture
import XCTest

@testable import Todos

class TodosTests: XCTestCase {
  let scheduler = DispatchQueue.test

  func testAddTodo() {
    let store = _TestStore(
      initialState: AppState(),
      reducer: AppReducer.main
        .dependency(\.uuid, .incrementing)
    )

    store.send(.addTodoButtonTapped) {
      $0.todos.insert(
        Todo(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        ),
        at: 0
      )
    }
  }

  func testEditTodo() {
    let state = AppState(
      todos: [
        Todo(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        )
      ]
    )
    let store = _TestStore(
      initialState: state,
      reducer: AppReducer.main
    )

    store.send(
      .todo(id: state.todos[0].id, action: .set(\.$description, "Learn Composable Architecture"))
    ) {
      $0.todos[id: state.todos[0].id]?.description = "Learn Composable Architecture"
    }
  }

  func testCompleteTodo() {
    let state = AppState(
      todos: [
        Todo(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        ),
        Todo(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          isComplete: false
        ),
      ]
    )
    let store = _TestStore(
      initialState: state,
      reducer: AppReducer.main
        .dependency(\.mainQueue, self.scheduler.eraseToAnyScheduler())
    )

    store.send(.todo(id: state.todos[0].id, action: .set(\.$isComplete, true))) {
      $0.todos[id: state.todos[0].id]?.isComplete = true
    }
    self.scheduler.advance(by: 1)
    store.receive(.sortCompletedTodos) {
      $0.todos = [
        $0.todos[1],
        $0.todos[0],
      ]
    }
  }

  func testCompleteTodoDebounces() {
    let state = AppState(
      todos: [
        Todo(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        ),
        Todo(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          isComplete: false
        ),
      ]
    )
    let store = _TestStore(
      initialState: state,
      reducer: AppReducer.main
        .dependency(\.mainQueue, self.scheduler.eraseToAnyScheduler())
    )

    store.send(.todo(id: state.todos[0].id, action: .set(\.$isComplete, true))) {
      $0.todos[id: state.todos[0].id]?.isComplete = true
    }
    self.scheduler.advance(by: 0.5)
    store.send(.todo(id: state.todos[0].id, action: .set(\.$isComplete, false))) {
      $0.todos[id: state.todos[0].id]?.isComplete = false
    }
    self.scheduler.advance(by: 1)
    store.receive(.sortCompletedTodos)
  }

  func testClearCompleted() {
    let state = AppState(
      todos: [
        Todo(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        ),
        Todo(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          isComplete: true
        ),
      ]
    )
    let store = _TestStore(
      initialState: state,
      reducer: AppReducer.main
    )

    store.send(.clearCompletedButtonTapped) {
      $0.todos = [
        $0.todos[0]
      ]
    }
  }

  func testDelete() {
    let state = AppState(
      todos: [
        Todo(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        ),
        Todo(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          isComplete: false
        ),
        Todo(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
          isComplete: false
        ),
      ]
    )
    let store = _TestStore(
      initialState: state,
      reducer: AppReducer.main
    )

    store.send(.delete([1])) {
      $0.todos = [
        $0.todos[0],
        $0.todos[2],
      ]
    }
  }

  func testEditModeMoving() {
    let state = AppState(
      todos: [
        Todo(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        ),
        Todo(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          isComplete: false
        ),
        Todo(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
          isComplete: false
        ),
      ]
    )
    let store = _TestStore(
      initialState: state,
      reducer: AppReducer.main
        .dependency(\.mainQueue, self.scheduler.eraseToAnyScheduler())
    )

    store.send(.editModeChanged(.active)) {
      $0.editMode = .active
    }
    store.send(.move([0], 2)) {
      $0.todos = [
        $0.todos[1],
        $0.todos[0],
        $0.todos[2],
      ]
    }
    self.scheduler.advance(by: .milliseconds(100))
    store.receive(.sortCompletedTodos)
  }

  func testFilteredEdit() {
    let state = AppState(
      todos: [
        Todo(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        ),
        Todo(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          isComplete: true
        ),
      ]
    )
    let store = _TestStore(
      initialState: state,
      reducer: AppReducer.main
    )

    store.send(.filterPicked(.completed)) {
      $0.filter = .completed
    }
    store.send(.todo(id: state.todos[1].id, action: .set(\.$description, "Did this already"))) {
      $0.todos[id: state.todos[1].id]?.description = "Did this already"
    }
  }
}
