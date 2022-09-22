import ComposableArchitecture
import XCTest

@testable import Todos

@MainActor
final class TodosTests: XCTestCase {
  let clock = TestClock()

  func testAddTodo() async {
    let store = TestStore(
      initialState: Todos.State(),
      reducer: Todos()
    )

    store.dependencies.uuid = .incrementing

    await store.send(.addTodoButtonTapped) {
      $0.todos.insert(
        Todo.State(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        ),
        at: 0
      )
    }

    await store.send(.addTodoButtonTapped) {
      $0.todos = [
        Todo.State(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          isComplete: false
        ),
        Todo.State(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
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
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        )
      ]
    )

    let store = TestStore(
      initialState: state,
      reducer: Todos()
    )

    await store.send(
      .todo(id: state.todos[0].id, action: .textFieldChanged("Learn Composable Architecture"))
    ) {
      $0.todos[id: state.todos[0].id]?.description = "Learn Composable Architecture"
    }
  }

  func testCompleteTodo() async {
    let state = Todos.State(
      todos: [
        Todo.State(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        ),
        Todo.State(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          isComplete: false
        ),
      ]
    )

    let store = TestStore(
      initialState: state,
      reducer: Todos()
    )

    store.dependencies.continuousClock = self.clock

    await store.send(.todo(id: state.todos[0].id, action: .checkBoxToggled)) {
      $0.todos[id: state.todos[0].id]?.isComplete = true
    }
    await self.clock.advance(by: .seconds(1))
    await store.receive(.sortCompletedTodos) {
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
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        ),
        Todo.State(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          isComplete: false
        ),
      ]
    )

    let store = TestStore(
      initialState: state,
      reducer: Todos()
    )

    store.dependencies.continuousClock = self.clock

    await store.send(.todo(id: state.todos[0].id, action: .checkBoxToggled)) {
      $0.todos[id: state.todos[0].id]?.isComplete = true
    }
    await self.clock.advance(by: .milliseconds(500))
    await store.send(.todo(id: state.todos[0].id, action: .checkBoxToggled)) {
      $0.todos[id: state.todos[0].id]?.isComplete = false
    }
    await self.clock.advance(by: .seconds(1))
    await store.receive(.sortCompletedTodos)
  }

  func testClearCompleted() async {
    let state = Todos.State(
      todos: [
        Todo.State(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        ),
        Todo.State(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          isComplete: true
        ),
      ]
    )

    let store = TestStore(
      initialState: state,
      reducer: Todos()
    )

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
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        ),
        Todo.State(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          isComplete: false
        ),
        Todo.State(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
          isComplete: false
        ),
      ]
    )

    let store = TestStore(
      initialState: state,
      reducer: Todos()
    )

    await store.send(.delete([1])) {
      $0.todos = [
        $0.todos[0],
        $0.todos[2],
      ]
    }
  }

  func testEditModeMoving() async {
    let state = Todos.State(
      todos: [
        Todo.State(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        ),
        Todo.State(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          isComplete: false
        ),
        Todo.State(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
          isComplete: false
        ),
      ]
    )

    let store = TestStore(
      initialState: state,
      reducer: Todos()
    )

    store.dependencies.continuousClock = self.clock

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
    await self.clock.advance(by: .milliseconds(100))
    await store.receive(.sortCompletedTodos)
  }

  func testEditModeMovingWithFilter() async {
    let state = Todos.State(
      todos: [
        Todo.State(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        ),
        Todo.State(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          isComplete: false
        ),
        Todo.State(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
          isComplete: true
        ),
        Todo.State(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
          isComplete: true
        ),
      ]
    )

    let store = TestStore(
      initialState: state,
      reducer: Todos()
    )

    store.dependencies.continuousClock = self.clock
    store.dependencies.uuid = .incrementing

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
    await self.clock.advance(by: .milliseconds(100))
    await store.receive(.sortCompletedTodos)
  }

  func testFilteredEdit() async {
    let state = Todos.State(
      todos: [
        Todo.State(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        ),
        Todo.State(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          isComplete: true
        ),
      ]
    )

    let store = TestStore(
      initialState: state,
      reducer: Todos()
    )

    await store.send(.filterPicked(.completed)) {
      $0.filter = .completed
    }
    await store.send(.todo(id: state.todos[1].id, action: .textFieldChanged("Did this already"))) {
      $0.todos[id: state.todos[1].id]?.description = "Did this already"
    }
  }
}
