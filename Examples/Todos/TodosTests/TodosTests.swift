import ComposableArchitecture
import XCTest

@testable import Todos

class TodosTests: XCTestCase {
  var events: [AnalyticsClient.Event] = []
  let scheduler = DispatchQueue.testScheduler

  func testAddTodo() {
    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: AppEnvironment(
        analytics: .failing,
        mainQueue: .failing,
        uuid: UUID.incrementing
      )
    )

    store.assert(
      .send(.addTodoButtonTapped) {
        $0.todos.insert(
          Todo(
            description: "",
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            isComplete: false
          ),
          at: 0
        )
      },
      .send(.addTodoButtonTapped) {
        $0.todos.insert(
          Todo(
            description: "",
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            isComplete: false
          ),
          at: 0
        )
      }
    )
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
    let store = TestStore(
      initialState: state,
      reducer: appReducer,
      environment: AppEnvironment(
        analytics: .failing,
        mainQueue: .failing,
        uuid: UUID.failing
      )
    )

    store.assert(
      .send(
        .todo(id: state.todos[0].id, action: .textFieldChanged("Learn Composable Architecture"))
      ) {
        $0.todos[0].description = "Learn Composable Architecture"
      }
    )
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
    let store = TestStore(
      initialState: state,
      reducer: appReducer,
      environment: AppEnvironment(
        analytics: .failing,
        mainQueue: self.scheduler.eraseToAnyScheduler(),
        uuid: UUID.failing
      )
    )

    store.send(.todo(id: state.todos[0].id, action: .checkBoxToggled)) {
      $0.todos[0].isComplete = true
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
    let store = TestStore(
      initialState: state,
      reducer: appReducer,
      environment: AppEnvironment(
        analytics: .failing,
        mainQueue: self.scheduler.eraseToAnyScheduler(),
        uuid: UUID.incrementing
      )
    )

    store.assert(
      .send(.todo(id: state.todos[0].id, action: .checkBoxToggled)) {
        $0.todos[0].isComplete = true
      },
      .do { self.scheduler.advance(by: 0.5) },
      .send(.todo(id: state.todos[0].id, action: .checkBoxToggled)) {
        $0.todos[0].isComplete = false
      },
      .do { self.scheduler.advance(by: 1) },
      .receive(.sortCompletedTodos)
    )
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
    let store = TestStore(
      initialState: state,
      reducer: appReducer,
      environment: AppEnvironment(
        analytics: .test(onEvent: { event in self.events.append(event) }),
        mainQueue: self.scheduler.eraseToAnyScheduler(),
        uuid: UUID.incrementing
      )
    )

    store.assert(
      .send(.clearCompletedButtonTapped) {
        $0.todos = [
          $0.todos[0]
        ]
      }
    )
    XCTAssertEqual(events, [.init(name: "Cleared Completed Todos")])
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
    let store = TestStore(
      initialState: state,
      reducer: appReducer,
      environment: AppEnvironment(
        analytics: .test { self.events.append($0) },
        mainQueue: .failing,
        uuid: UUID.failing
      )
    )

    store.send(.delete([1])) {
      $0.todos = [
        $0.todos[0],
        $0.todos[2],
      ]
    }

    XCTAssertEqual(
      self.events,
      [
        .init(name: "Todo Deleted", properties: ["editMode": "inactive"]),
      ]
    )

    store.send(.editModeChanged(.active)) {
      $0.editMode = .active
    }
    store.send(.delete([0])) {
      $0.todos = [
        $0.todos[1]
      ]
    }

    XCTAssertEqual(
      events,
      [
        .init(name: "Todo Deleted", properties: ["editMode": "inactive"]),
        .init(name: "Todo Deleted", properties: ["editMode": "active"]),
      ]
    )
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
    let store = TestStore(
      initialState: state,
      reducer: appReducer,
      environment: AppEnvironment(
        analytics: .failing,
        mainQueue: self.scheduler.eraseToAnyScheduler(),
        uuid: UUID.incrementing
      )
    )

    store.assert(
      .send(.editModeChanged(.active)) {
        $0.editMode = .active
      },
      .send(.move([0], 2)) {
        $0.todos = [
          $0.todos[1],
          $0.todos[0],
          $0.todos[2],
        ]
      },
      .do { self.scheduler.advance(by: .milliseconds(100)) },
      .receive(.sortCompletedTodos)
    )
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
    let store = TestStore(
      initialState: state,
      reducer: appReducer,
      environment: AppEnvironment(
        analytics: .test(onEvent: { self.events.append($0) }),
        mainQueue: self.scheduler.eraseToAnyScheduler(),
        uuid: UUID.incrementing
      )
    )

    store.assert(
      .send(.filterPicked(.completed)) {
        $0.filter = .completed
      },
      .do {
        XCTAssertEqual(
          self.events,
          [.init(name: "Filter Changed", properties: ["filter": "completed"])]
        )
      },
      .send(.todo(id: state.todos[1].id, action: .textFieldChanged("Did this already"))) {
        $0.todos[1].description = "Did this already"
      }
    )
  }
}
