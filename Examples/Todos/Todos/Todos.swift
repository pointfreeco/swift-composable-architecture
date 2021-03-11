import ComposableArchitecture
import SwiftUI

enum Filter: LocalizedStringKey, CaseIterable, Hashable {
  case all = "All"
  case active = "Active"
  case completed = "Completed"
}

struct AppState: Equatable {
  var editMode: EditMode = .inactive
  var filter: Filter = .all
  var todos: IdentifiedArrayOf<Todo> = []

  var filteredTodos: IdentifiedArrayOf<Todo> {
    switch filter {
    case .active: return self.todos.filter { !$0.isComplete }
    case .all: return self.todos
    case .completed: return self.todos.filter { $0.isComplete }
    }
  }
}

enum AppAction: Equatable {
  case addTodoButtonTapped
  case clearCompletedButtonTapped
  case delete(IndexSet)
  case editModeChanged(EditMode)
  case filterPicked(Filter)
  case move(IndexSet, Int)
  case sortCompletedTodos
  case todo(id: UUID, action: TodoAction)
}

struct AppEnvironment {
  var analyticsClient: AnalyticsClient
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var uuid: () -> UUID
}

let appReducer = Reducer<AppState, AppAction, AppEnvironment>.combine(
  todoReducer.forEach(
    state: \.todos,
    action: /AppAction.todo(id:action:),
    environment: { _ in TodoEnvironment() }
  ),
  Reducer { state, action, environment in
    switch action {
    case .addTodoButtonTapped:
      state.todos.insert(Todo(id: environment.uuid()), at: 0)
      return .none

    case .clearCompletedButtonTapped:
      state.todos.removeAll(where: { $0.isComplete })
      return environment.analyticsClient.track(.init(name: "Cleared Completed Todos", properties: [:]))
        .fireAndForget()

    case let .delete(indexSet):
//      _ = environment.uuid()
      state.todos.remove(atOffsets: indexSet)
      return environment.analyticsClient.track(
        .init(
          name: "Todo Deleted",
          properties: ["editMode": "\(state.editMode)"]
        )
      )
        .fireAndForget()

    case let .editModeChanged(editMode):
      state.editMode = editMode
      return .none

    case let .filterPicked(filter):
      state.filter = filter
      return environment.analyticsClient
        .track(.init(name: "Filter Changed", properties: ["filter": "\(filter)"]))
        .fireAndForget()

    case let .move(source, destination):
      state.todos.move(fromOffsets: source, toOffset: destination)
      return Effect(value: .sortCompletedTodos)
        .delay(for: .milliseconds(100), scheduler: environment.mainQueue)
        .eraseToEffect()

    case .sortCompletedTodos:
      state.todos.sortCompleted()
      return .none

    case .todo(id: _, action: .checkBoxToggled):
      struct TodoCompletionId: Hashable {}
      return Effect(value: .sortCompletedTodos)
        .debounce(id: TodoCompletionId(), for: 1, scheduler: environment.mainQueue.animation())

    case .todo:
      return .none
    }
  }
)

struct AppView: View {
  struct ViewState: Equatable {
    var editMode: EditMode
    var isClearCompletedButtonDisabled: Bool
  }

  let store: Store<AppState, AppAction>

  var body: some View {
    WithViewStore(self.store.scope(state: { $0.view })) { viewStore in
      NavigationView {
        VStack(alignment: .leading) {
          WithViewStore(self.store.scope(state: { $0.filter }, action: AppAction.filterPicked)) {
            filterViewStore in
            Picker(
              "Filter", selection: filterViewStore.binding(send: { $0 }).animation()
            ) {
              ForEach(Filter.allCases, id: \.self) { filter in
                Text(filter.rawValue).tag(filter)
              }
            }
            .pickerStyle(SegmentedPickerStyle())
          }
          .padding([.leading, .trailing])

          List {
            ForEachStore(
              self.store.scope(state: { $0.filteredTodos }, action: AppAction.todo(id:action:)),
              content: TodoView.init(store:)
            )
            .onDelete { viewStore.send(.delete($0)) }
            .onMove { viewStore.send(.move($0, $1)) }
          }
        }
        .navigationBarTitle("Todos")
        .navigationBarItems(
          trailing: HStack(spacing: 20) {
            EditButton()
            Button("Clear Completed") {
              viewStore.send(.clearCompletedButtonTapped, animation: .default)
            }
            .disabled(viewStore.isClearCompletedButtonDisabled)
            Button("Add Todo") { viewStore.send(.addTodoButtonTapped, animation: .default) }
          }
        )
        .environment(
          \.editMode,
          viewStore.binding(get: { $0.editMode }, send: AppAction.editModeChanged)
        )
      }
      .navigationViewStyle(StackNavigationViewStyle())
    }
  }
}

extension AppState {
  var view: AppView.ViewState {
    .init(
      editMode: self.editMode,
      isClearCompletedButtonDisabled: !self.todos.contains(where: { $0.isComplete })
    )
  }
}

extension IdentifiedArray where ID == UUID, Element == Todo {
  fileprivate mutating func sortCompleted() {
    // Simulate stable sort
    self = IdentifiedArray(
      self.enumerated()
        .sorted(by: { lhs, rhs in
          (rhs.element.isComplete && !lhs.element.isComplete) || lhs.offset < rhs.offset
        })
        .map { $0.element }
    )
  }
}

extension IdentifiedArray where ID == UUID, Element == Todo {
  static let mock: Self = [
    Todo(
      description: "Check Mail",
      id: UUID(uuidString: "DEADBEEF-DEAD-BEEF-DEAD-BEEDDEADBEEF")!,
      isComplete: false
    ),
    Todo(
      description: "Buy Milk",
      id: UUID(uuidString: "CAFEBEEF-CAFE-BEEF-CAFE-BEEFCAFEBEEF")!,
      isComplete: false
    ),
    Todo(
      description: "Call Mom",
      id: UUID(uuidString: "D00DCAFE-D00D-CAFE-D00D-CAFED00DCAFE")!,
      isComplete: true
    ),
  ]
}

struct AppView_Previews: PreviewProvider {
  static var previews: some View {
    AppView(
      store: Store(
        initialState: AppState(todos: .mock),
        reducer: appReducer,
        environment: AppEnvironment(
          analyticsClient: .live,
          mainQueue: DispatchQueue.main.eraseToAnyScheduler(),
          uuid: UUID.init
        )
      )
    )
  }
}



import ComposableArchitecture

public struct AnalyticsClient {
  public var track: (Event) -> Effect<Never, Never>

  public struct Event: Equatable {
    public var name: String
    public var properties: [String: String] = [:]
  }
}

#if canImport(XCTest)
import XCTest

extension Effect {
  static func failing(_ title: String) -> Self {
    .fireAndForget {
      XCTFail("\(title): Effect is unimplemented")
    }
  }
}

extension AnalyticsClient {
  public static let unimplemented = Self(
    track: { _ in
      fatalError("Track is unimplemented")
    }
  )

  public static let failing = Self(
    track: { _ in
      .failing("AnalyticsClient.track")
    }
  )
}

extension AnalyticsClient {
  public static let live = Self(
    track: { event in
      .fireAndForget {
        print("Track name: \"\(event.name)\", properties: \(event.properties)")
        // TODO: prep the URL to send analytics
        URLSession.shared.dataTask(with: URL(string: "https://www.my-company.com/analytics")!)
          .resume()
      }
    }
  )

  public static let noop = Self(
    track: { _ in
      .fireAndForget {}
    }
  )

  public static func test(onEvent: @escaping (Event) -> Void) -> Self {
    .init(
      track: { event in
        .fireAndForget {
          onEvent(event)
        }
      }
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
#endif
