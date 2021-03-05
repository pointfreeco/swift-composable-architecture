import ComposableArchitecture
import XCTest

@testable import Todos

class TodosTests: XCTestCase {
  let scheduler = DispatchQueue.testScheduler

  func testAddTodo() {
    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: AppEnvironment(
        analyticsClient: .failing,
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
    let todo = Todo(
      description: "",
      id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
      isComplete: false
    )
    let store = TestStore(
      initialState: AppState(todos: [todo]),
      reducer: appReducer,
      environment: AppEnvironment(
        analyticsClient: .failing,
        mainQueue: .failing,
        uuid: UUID.failing
      )
    )

    store.assert(
      .send(.todo(id: todo.id, action: .textFieldChanged("Learn Composable Architecture"))) {
        $0.todos[0].description = "Learn Composable Architecture"
      }
    )
  }

  func testCompleteTodo() {
    let todos: IdentifiedArrayOf<Todo> = [
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
    let failingScheduler = DispatchQueue.failing
    let store = TestStore(
      initialState: AppState(todos: todos),
      reducer: appReducer,
      environment: AppEnvironment(
        analyticsClient: .failing,
        mainQueue: .failing,
        uuid: UUID.failing
      )
    )

//    TestStore.Step


    store.send(.todo(id: todos[0].id, action: .checkBoxToggled)) {
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
        analyticsClient: .failing,
        mainQueue: self.scheduler.eraseToAnyScheduler(),
        uuid: UUID.failing
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
    var events: [AnalyticsClient.Event] = []
    let store = TestStore(
      initialState: state,
      reducer: appReducer,
      environment: AppEnvironment(
        analyticsClient: .test { events.append($0) },
        mainQueue: self.scheduler.eraseToAnyScheduler(),
        uuid: UUID.failing
      )
    )

    store.assert(
      .send(.clearCompletedButtonTapped) {
        $0.todos.remove(at: 1)
      }
    )

    XCTAssertEqual(events, [.init(name: "Cleared Completed Todos")])
  }

  func testDelete() {
    let todos: IdentifiedArrayOf<Todo> = [
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
    var events: [AnalyticsClient.Event] = []
    let store = TestStore(
      initialState: .init(todos: todos),
      reducer: appReducer,
      environment: AppEnvironment(
        analyticsClient: .test { events.append($0) },
        mainQueue: .failing,
        uuid: UUID.failing
      )
    )

    store.assert(
      .send(.delete([1])) {
        $0.todos.remove(at: 1)
      },
      .send(.editModeChanged(.active)) {
        $0.editMode = .active
      },
      .send(.delete([0])) {
        $0.todos.remove(at: 0)
      }
    )
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
        analyticsClient: .failing,
        mainQueue: self.scheduler.eraseToAnyScheduler(),
        uuid: UUID.failing
      )
    )

//    store.send(.editModeChanged(.active)) {
//      $0.editMode = .active
//    }
//    store.send(.move([0], 2)) {
//      $0.todos = [
//        $0.todos[1],
//        $0.todos[0],
//        $0.todos[2],
//      ]
//    }
//
//    self.scheduler.advance(by: .milliseconds(100))
//    store.receive(.sortCompletedTodos)
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
    var events: [AnalyticsClient.Event] = []
    let store = TestStore(
      initialState: state,
      reducer: appReducer,
      environment: AppEnvironment(
        analyticsClient: .test { events.append($0) },
        mainQueue: self.scheduler.eraseToAnyScheduler(),
        uuid: UUID.failing
      )
    )

    store.assert(
      .send(.filterPicked(.completed)) {
        $0.filter = .completed
      },
      .send(.todo(id: state.todos[1].id, action: .textFieldChanged("Did this already"))) {
        $0.todos[1].description = "Did this already"
      }
    )
    XCTAssertEqual(
      events,
      [.init(name: "Filter Changed", properties: ["filter": "completed"])]
    )
  }
}


extension UUID {
  // A deterministic, auto-incrementing "UUID" generator for testing.
  static var incrementing: () -> UUID {
    var uuid = 0
    return {
      defer { uuid += 1 }
      return UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012x", uuid))")!
    }
  }

  static var failing: () -> UUID {
    {
      XCTFail("UUID initializer is unimplemented")
      return UUID()
    }
  }
}

extension UUID {
  static let unimplemented: () -> UUID = { fatalError() }
}

extension AnyScheduler {
  static var unimplemented: Self {
    Self(
      minimumTolerance: { fatalError() },
      now: { fatalError() },
      scheduleImmediately: { _, _ in fatalError() },
      delayed: { _, _, _, _ in fatalError() },
      interval: { _, _, _, _, _ in fatalError() }
    )
  }
}

extension AnalyticsClient {
  static let unimplemented = Self(
    track: { _ in
      fatalError("Track is unimplemented")
    }
  )

  static let failing = Self(
    track: { _ in
      .failing("Analytics Client track")
    }
  )
}

extension Effect {
  static func failing(_ title: String) -> Self {
    .fireAndForget {
      XCTFail("\(title): Effect is unimplemented")
    }
  }
}

import Combine

extension Scheduler {
  public static func failing(
    minimumTolerance: @escaping () -> SchedulerTimeType.Stride,
    now: @escaping () -> SchedulerTimeType
  ) -> AnySchedulerOf<Self> {
    .init(
      minimumTolerance: {
        XCTFail("Scheduler.minimumTolerance is unimplemented")
        return minimumTolerance()
      },
      now: {
        XCTFail("Scheduler.now is unimplemented")
        return now()
      },
      scheduleImmediately: { options, action in
        XCTFail("Scheduler.scheduleImmediately is unimplemented")
      },
      delayed: { delay, tolerance, options, action in
        XCTFail("Scheduler.delayed is unimplemented")
      },
      interval: { delay, interval, tolerance, options, action in
        XCTFail("Scheduler.interval is unimplemented")
        return AnyCancellable {}
      }
    )
  }
}

extension Scheduler
where
  SchedulerTimeType == DispatchQueue.SchedulerTimeType,
  SchedulerOptions == DispatchQueue.SchedulerOptions
{
  public static var failing: AnySchedulerOf<Self> {
    AnySchedulerOf<Self>.failing(
      minimumTolerance: { .zero },
      now: { .init(.init(uptimeNanoseconds: 1)) }
    )
  }
}
