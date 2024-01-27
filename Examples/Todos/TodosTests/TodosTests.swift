import ComposableArchitecture
import XCTest

@testable import Todos

@MainActor
final class TodosTests: XCTestCase {
  let clock = TestClock()

  func testAddTodo() async {
    let store = TestStore(initialState: Todos.State()) {
      Todos()
    } withDependencies: {
      $0.uuid = .incrementing
    }

    await store.send(.addTodoButtonTapped) {
      $0.todos.insert(
        Todo.State(
          description: "",
          id: UUID(0),
          isComplete: false
        ),
        at: 0
      )
    }

    await store.send(.addTodoButtonTapped) {
      $0.todos = [
        Todo.State(
          description: "",
          id: UUID(1),
          isComplete: false
        ),
        Todo.State(
          description: "",
          id: UUID(0),
          isComplete: false
        ),
      ]
    }
  }

  func testEditTodo() async {
    let state = Todos.State(
      todos: [
        Todo.State(
          description: "",
          id: UUID(0),
          isComplete: false
        )
      ]
    )

    let store = TestStore(initialState: state) {
      Todos()
    }

    await store.send(
      .todos(
        .element(
          id: state.todos[0].id, action: .set(\.description, "Learn Composable Architecture")
        )
      )
    ) {
      $0.todos[id: state.todos[0].id]?.description = "Learn Composable Architecture"
    }
  }

  func testCompleteTodo() async {
    let state = Todos.State(
      todos: [
        Todo.State(
          description: "",
          id: UUID(0),
          isComplete: false
        ),
        Todo.State(
          description: "",
          id: UUID(1),
          isComplete: false
        ),
      ]
    )

    let store = TestStore(initialState: state) {
      Todos()
    } withDependencies: {
      $0.continuousClock = self.clock
    }

    await store.send(.todos(.element(id: state.todos[0].id, action: .set(\.isComplete, true)))) {
      $0.todos[id: state.todos[0].id]?.isComplete = true
    }
    await self.clock.advance(by: .seconds(1))
    await store.receive(\.sortCompletedTodos) {
      $0.todos = [
        $0.todos[1],
        $0.todos[0],
      ]
    }
  }

  func testCompleteTodoDebounces() async {
    let state = Todos.State(
      todos: [
        Todo.State(
          description: "",
          id: UUID(0),
          isComplete: false
        ),
        Todo.State(
          description: "",
          id: UUID(1),
          isComplete: false
        ),
      ]
    )

    let store = TestStore(initialState: state) {
      Todos()
    } withDependencies: {
      $0.continuousClock = self.clock
    }

    await store.send(.todos(.element(id: state.todos[0].id, action: .set(\.isComplete, true)))) {
      $0.todos[id: state.todos[0].id]?.isComplete = true
    }
    await self.clock.advance(by: .milliseconds(500))
    await store.send(.todos(.element(id: state.todos[0].id, action: .set(\.isComplete, false)))) {
      $0.todos[id: state.todos[0].id]?.isComplete = false
    }
    await self.clock.advance(by: .seconds(1))
    await store.receive(\.sortCompletedTodos)
  }

  func testClearCompleted() async {
    let state = Todos.State(
      todos: [
        Todo.State(
          description: "",
          id: UUID(0),
          isComplete: false
        ),
        Todo.State(
          description: "",
          id: UUID(1),
          isComplete: true
        ),
      ]
    )

    let store = TestStore(initialState: state) {
      Todos()
    }

    await store.send(.clearCompletedButtonTapped) {
      $0.todos = [
        $0.todos[0]
      ]
    }
  }

  func testDelete() async {
    let state = Todos.State(
      todos: [
        Todo.State(
          description: "",
          id: UUID(0),
          isComplete: false
        ),
        Todo.State(
          description: "",
          id: UUID(1),
          isComplete: false
        ),
        Todo.State(
          description: "",
          id: UUID(2),
          isComplete: false
        ),
      ]
    )

    let store = TestStore(initialState: state) {
      Todos()
    }

    await store.send(.delete([1])) {
      $0.todos = [
        $0.todos[0],
        $0.todos[2],
      ]
    }
  }

  func testDeleteWhileFiltered() async {
    let state = Todos.State(
      filter: .completed,
      todos: [
        Todo.State(
          description: "",
          id: UUID(0),
          isComplete: false
        ),
        Todo.State(
          description: "",
          id: UUID(1),
          isComplete: false
        ),
        Todo.State(
          description: "",
          id: UUID(2),
          isComplete: true
        ),
      ]
    )

    let store = TestStore(initialState: state) {
      Todos()
    }

    await store.send(.delete([0])) {
      $0.todos = [
        $0.todos[0],
        $0.todos[1],
      ]
    }
  }

  func testEditModeMoving() async {
    let state = Todos.State(
      todos: [
        Todo.State(
          description: "",
          id: UUID(0),
          isComplete: false
        ),
        Todo.State(
          description: "",
          id: UUID(1),
          isComplete: false
        ),
        Todo.State(
          description: "",
          id: UUID(2),
          isComplete: false
        ),
      ]
    )

    let store = TestStore(initialState: state) {
      Todos()
    } withDependencies: {
      $0.continuousClock = self.clock
    }

    await store.send(.set(\.editMode, .active)) {
      $0.editMode = .active
    }
    await store.send(.move([0], 2)) {
      $0.todos = [
        $0.todos[1],
        $0.todos[0],
        $0.todos[2],
      ]
    }
    await self.clock.advance(by: .milliseconds(100))
    await store.receive(\.sortCompletedTodos)
  }

  func testEditModeMovingWithFilter() async {
    let state = Todos.State(
      todos: [
        Todo.State(
          description: "",
          id: UUID(0),
          isComplete: false
        ),
        Todo.State(
          description: "",
          id: UUID(1),
          isComplete: false
        ),
        Todo.State(
          description: "",
          id: UUID(2),
          isComplete: true
        ),
        Todo.State(
          description: "",
          id: UUID(3),
          isComplete: true
        ),
      ]
    )

    let store = TestStore(initialState: state) {
      Todos()
    } withDependencies: {
      $0.continuousClock = self.clock
      $0.uuid = .incrementing
    }

    await store.send(.set(\.editMode, .active)) {
      $0.editMode = .active
    }
    await store.send(.set(\.filter, .completed)) {
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
    await self.clock.advance(by: .milliseconds(100))
    await store.receive(\.sortCompletedTodos)
  }

  func testFilteredEdit() async {
    let state = Todos.State(
      todos: [
        Todo.State(
          description: "",
          id: UUID(0),
          isComplete: false
        ),
        Todo.State(
          description: "",
          id: UUID(1),
          isComplete: true
        ),
      ]
    )

    let store = TestStore(initialState: state) {
      Todos()
    }

    await store.send(.set(\.filter, .completed)) {
      $0.filter = .completed
    }
    await store.send(
      .todos(.element(id: state.todos[1].id, action: .set(\.description, "Did this already")))
    ) {
      $0.todos[id: state.todos[1].id]?.description = "Did this already"
    }
  }
}
