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
  var analytics: AnalyticsClient
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
      return environment.analytics.track(.init(name: "Cleared Completed Todos"))
        .fireAndForget()

    case let .delete(indexSet):
      state.todos.remove(atOffsets: indexSet)
      return environment.analytics.track(
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
      return .none

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
          analytics: .live,
          mainQueue: DispatchQueue.main.eraseToAnyScheduler(),
          uuid: UUID.init
        )
      )
    )
  }
}

struct AnalyticsClient {
  let track: (Event) -> Effect<Never, Never>

  struct Event: Equatable {
    var name: String
    var properties: [String: String] = [:]
  }
}

extension AnalyticsClient {
  static let live = Self(
    track: { event in
      .fireAndForget {
        print("Track name: \(event.name), properties: \(event.properties)")
        // TODO: send the event data to the analytics server
//        URLSession.shared.dataTask(with: URL(string: "https://www.my-company.com/analytics")!)
//          .resume()
      }
    }
  )
}
