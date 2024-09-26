import ComposableArchitecture
import Foundation
import Testing

@testable import Todos

@MainActor
struct TodosTests {
  let clock = TestClock()

  @Test
  func add() async {
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

  @Test
  func edit() async {
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

    await store.send(\.todos[id: UUID(0)].binding.description, "Learn Composable Architecture") {
      $0.todos[id: UUID(0)]?.description = "Learn Composable Architecture"
    }
  }

  @Test
  func complete() async {
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
      $0.continuousClock = clock
    }

    await store.send(\.todos[id: UUID(0)].binding.isComplete, true) {
      $0.todos[id: UUID(0)]?.isComplete = true
    }
    await clock.advance(by: .seconds(1))
    await store.receive(\.sortCompletedTodos) {
      $0.todos = [
        $0.todos[1],
        $0.todos[0],
      ]
    }
  }

  @Test
  func completionDebounce() async {
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
      $0.continuousClock = clock
    }

    await store.send(\.todos[id: UUID(0)].binding.isComplete, true) {
      $0.todos[id: UUID(0)]?.isComplete = true
    }
    await clock.advance(by: .milliseconds(500))
    await store.send(\.todos[id: UUID(0)].binding.isComplete, false) {
      $0.todos[id: UUID(0)]?.isComplete = false
    }
    await clock.advance(by: .seconds(1))
    await store.receive(\.sortCompletedTodos)
  }

  @Test
  func clearCompleted() async {
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

  @Test
  func delete() async {
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

  @Test
  func filteredDelete() async {
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

  @Test
  func editModeMove() async {
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
      $0.continuousClock = clock
    }

    await store.send(\.binding.editMode, .active) {
      $0.editMode = .active
    }
    await store.send(.move([0], 2)) {
      $0.todos = [
        $0.todos[1],
        $0.todos[0],
        $0.todos[2],
      ]
    }
    await clock.advance(by: .milliseconds(100))
    await store.receive(\.sortCompletedTodos)
  }

  @Test
  func filteredEditModeMove() async {
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
      $0.continuousClock = clock
      $0.uuid = .incrementing
    }

    await store.send(\.binding.editMode, .active) {
      $0.editMode = .active
    }
    await store.send(\.binding.filter, .completed) {
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
    await clock.advance(by: .milliseconds(100))
    await store.receive(\.sortCompletedTodos)
  }

  @Test
  func filteredEdit() async {
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

    await store.send(\.binding.filter, .completed) {
      $0.filter = .completed
    }
    await store.send(\.todos[id: UUID(1)].binding.description, "Did this already") {
      $0.todos[id: UUID(1)]?.description = "Did this already"
    }
  }
}
