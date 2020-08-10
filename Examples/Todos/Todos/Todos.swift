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
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var uuid: () -> UUID
}

let appReducer = Reducer<AppState, AppAction, AppEnvironment>.combine(
  Reducer { state, action, environment in
    switch action {
    case .addTodoButtonTapped:
      state.todos.insert(Todo(id: environment.uuid()), at: 0)
      return .none

    case .clearCompletedButtonTapped:
      state.todos.removeAll(where: { $0.isComplete })
      return .none

    case let .delete(indexSet):
      state.todos.remove(atOffsets: indexSet)
      return .none

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
        .debounce(id: TodoCompletionId(), for: 1, scheduler: environment.mainQueue)

    case .todo:
      return .none
    }
  },
  todoReducer.forEach(
    state: \.todos,
    action: /AppAction.todo(id:action:),
    environment: { _ in TodoEnvironment() }
  )
)

.debugActions(actionFormat: .labelsOnly)

struct TutorialStepEnvironmentKey: EnvironmentKey {
  static var defaultValue: TutorialStep? = nil
}
extension EnvironmentValues {
  var tutorialStep: TutorialStep? {
    get { self[TutorialStepEnvironmentKey.self] }
    set { self[TutorialStepEnvironmentKey.self] = newValue }
  }
}

struct AppView: View {
  struct ViewState: Equatable {
    var editMode: EditMode
    var isClearCompletedButtonDisabled: Bool
  }

  let store: Store<AppState, AppAction>
  @Environment(\.tutorialStep) var tutorialStep

  var body: some View {
    WithViewStore(self.store.scope(state: { $0.view })) { viewStore in
      NavigationView {
        VStack(alignment: .leading) {
          WithViewStore(self.store.scope(state: { $0.filter }, action: AppAction.filterPicked)) {
            filterViewStore in
            Picker(
              "Filter", selection: filterViewStore.binding(send: { $0 })
            ) {
              ForEach(Filter.allCases, id: \.self) { filter in
                Text(filter.rawValue).tag(filter)
              }
            }
            .pickerStyle(SegmentedPickerStyle())
          }
          .padding([.leading, .trailing])
          .unredacted(if: self.tutorialStep == .filters)

          List {
            ForEachStore(
              self.store.scope(state: { $0.filteredTodos }, action: AppAction.todo(id:action:)),
              content: TodoView.init(store:)
            )
            .onDelete { viewStore.send(.delete($0)) }
            .onMove { viewStore.send(.move($0, $1)) }
          }
          .unredacted(if: self.tutorialStep == .todos)
        }
        .navigationBarTitle("Todos")
        .navigationBarItems(
          trailing: HStack(spacing: 20) {
            EditButton()
            Button("Clear Completed") { viewStore.send(.clearCompletedButtonTapped) }
              .disabled(viewStore.isClearCompletedButtonDisabled)
            Button("Add Todo") { viewStore.send(.addTodoButtonTapped) }
              .redacted(reason: RedactionReasons.init(rawValue: 0))
          }
          .unredacted(if: self.tutorialStep == .actions)
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

extension View {
  @ViewBuilder func unredacted(if condition: Bool) -> some View {
    if condition {
      self.unredacted()
    } else {
      self
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

enum TutorialStep: Equatable {
  case actions
  case filters
  case todos
}

struct TutorialState: Equatable {
  var app: AppState
  var tutorialStep: TutorialStep?
}

enum TutorialAction {
  case app(AppAction)
  case nextButtonTapped
  case previousButtonTapped
  case skipButtonTapped
}

let tutorialReducer = Reducer<TutorialState, TutorialAction, AppEnvironment> { state, action, env in
  switch action {
  case let .app(.filterPicked(filter)):
    guard state.tutorialStep == .filters else { return .none }
    state.app.filter = filter
    return .none

  case let .app(action):
    guard state.tutorialStep == .todos else { return .none }

    switch action {
    case .sortCompletedTodos, .todo(id: _, action: .checkBoxToggled):
      return appReducer
        .run(&state.app, action, env)
        .map(TutorialAction.app)

    default: return .none
    }

  case .nextButtonTapped:
    switch state.tutorialStep {
    case .actions:
      state.tutorialStep = .filters
    case .filters:
      state.tutorialStep = .todos
      state.app.filter = .all
    case .todos:
      state.tutorialStep = nil
    case .none:
      break
    }
    return .none

  case .previousButtonTapped:
    switch state.tutorialStep {
    case .actions:
      break
    case .filters:
      state.tutorialStep = .actions
    case .todos:
      state.tutorialStep = .filters
    case .none:
      break
    }
    return .none

  case .skipButtonTapped:
    state.tutorialStep = nil
    return .none
  }
}

struct TutorialView: View {
  let tutorialStore: Store<TutorialState, TutorialAction>
  let appStore: Store<AppState, AppAction>

  var body: some View {
    WithViewStore(self.tutorialStore) { tutorialViewStore in
      if tutorialViewStore.tutorialStep != nil {
        ZStack {
          AppView(store: self.tutorialStore.scope(state: \.app, action: TutorialAction.app))
            .environment(\.tutorialStep, tutorialViewStore.tutorialStep)
            .redacted(reason: .placeholder)

          VStack {
            Spacer()

            HStack(alignment: .top) {
              Button(action: { tutorialViewStore.send(.previousButtonTapped) }) {
                Image(systemName: "chevron.left")
              }
              .disabled(tutorialViewStore.tutorialStep == .actions)
              .frame(width: 44, height: 44)
              .foregroundColor(.white)
              .background(Color.gray)
              .clipShape(Circle())
              .padding([.leading, .trailing])

              Spacer()
              VStack {
                switch tutorialViewStore.tutorialStep {
                case .actions:
                  Text("Use the navbar actions to mass delete todos, clear all your completed todos, or add a new one.")
                case .filters:
                  Text("Use the filters bar to change what todos are currently displayed to you. Try changing a filter.")
                case .todos:
                  Text("Here's your list of todos. You can check one off to complete it, or edit its title by tapping on the current title.")
                case .none:
                  Text("Hi")
                }
                Button("Skip") { tutorialViewStore.send(.skipButtonTapped) }
                  .padding()
              }
              Spacer()
              Button(action: { tutorialViewStore.send(.nextButtonTapped) }) {
                Image(systemName: "chevron.right")
              }
              .frame(width: 44, height: 44)
              .background(Color.gray)
              .foregroundColor(.white)
              .clipShape(Circle())
              .padding([.leading, .trailing])

            }
            .padding(.top, 400)
            .padding(.bottom, 100)
            .background(LinearGradient(gradient: Gradient(colors: [.init(white: 1, opacity: 0), .init(white: 0.8, opacity: 1)]), startPoint: .top, endPoint: .bottom))
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      } else {
        AppView(store: self.appStore)
      }
    }
  }
}

struct TutorialView_Previews: PreviewProvider {
  static var previews: some View {
    TutorialView(
      tutorialStore: Store(
        initialState: TutorialState(app: .init(todos: .placeholder), tutorialStep: .actions),
        reducer: tutorialReducer,
        environment: AppEnvironment(mainQueue: DispatchQueue.main.eraseToAnyScheduler(), uuid: UUID.init)
      ),
      appStore: Store(
        initialState: .init(),
        reducer: appReducer,
        environment: AppEnvironment(
          mainQueue: DispatchQueue.main.eraseToAnyScheduler(),
          uuid: UUID.init
        )
      )
    )
  }
}

extension IdentifiedArray where ID == UUID, Element == Todo {
  static let placeholder: Self = [
    Todo(
      description: "Check Mail",
      id: UUID(),
      isComplete: false
    ),
    Todo(
      description: "Buy Milk",
      id: UUID(),
      isComplete: false
    ),
    Todo(
      description: "Get haircut",
      id: UUID(),
      isComplete: false
    ),
    Todo(
      description: "Write meeting notes",
      id: UUID(),
      isComplete: false
    ),
    Todo(
      description: "Email Blob",
      id: UUID(),
      isComplete: false
    ),
    Todo(
      description: "Return book",
      id: UUID(),
      isComplete: true
    ),
    Todo(
      description: "Pack for trip",
      id: UUID(),
      isComplete: true
    ),
    Todo(
      description: "Prep lunch for the week",
      id: UUID(),
      isComplete: true
    ),
    Todo(
      description: "Call Mom",
      id: UUID(),
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
          mainQueue: DispatchQueue.main.eraseToAnyScheduler(),
          uuid: UUID.init
        )
      )
    )
  }
}
