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

struct AnalyticsClient {
  var track: (String, [String: String]) -> Effect<Never, Never>
}

extension AnalyticsClient {
  static func onboarding(_ client: Self) -> Self {
    .init(
      track: { event, properties in
        client.track(
          "[Onboarding] \(event)",
          properties.merging(["onboarding": "true"], uniquingKeysWith: { $1 })
        )
      }
    )
  }
}

extension AnalyticsClient {
  static let noop = Self(track: { _, _ in .fireAndForget { } })

  static let live = Self(
    track: { event, properties in
      .fireAndForget {
        // perform URL request to send event to your analytics server
      }
    }
  )
}

struct AppEnvironment {
  var analytics: AnalyticsClient
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var uuid: () -> UUID
}

let appReducer = Reducer<AppState, AppAction, AppEnvironment>.combine(
  Reducer { state, action, environment in
    switch action {
    case .addTodoButtonTapped:
      state.todos.insert(Todo(id: environment.uuid()), at: 0)
      return environment.analytics.track("Add Todo", [:])
        .fireAndForget()

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

struct AppView: View {
  struct ViewState: Equatable {
    var editMode: EditMode
    var isClearCompletedButtonDisabled: Bool
  }

  let store: Store<AppState, AppAction>
  @Environment(\.onboardingStep) var onboardingStep

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
            .unredacted(if: self.onboardingStep == .filters)
//            .unredacted()
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
          .unredacted(if: self.onboardingStep == .todos)
        }
        .navigationBarTitle("Todos")
        .navigationBarItems(
          trailing: HStack(spacing: 20) {
            EditButton()
            Button("Clear Completed") { viewStore.send(.clearCompletedButtonTapped) }
              .disabled(viewStore.isClearCompletedButtonDisabled)
            Button("Add Todo") { viewStore.send(.addTodoButtonTapped) }
          }
          .unredacted(if: self.onboardingStep == .actions)
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

enum OnboardingStep: Equatable {
  case actions
  case filters
  case todos

  var next: Self? {
    switch self {
    case .actions:
      return .filters
    case .filters:
      return .todos
    case .todos:
      return nil
    }
  }

  var previous: Self? {
    switch self {
    case .actions:
      return nil
    case .filters:
      return .actions
    case .todos:
      return .filters
    }
  }
}

struct OnboardingState: Equatable {
  var placeholderApp: AppState
  var step: OnboardingStep?
}

enum OnboardingAction {
  case app(AppAction)
  case nextButtonTapped
  case previousButtonTapped
  case skipButtonTapped
}

let onboardingReducer = Reducer<OnboardingState, OnboardingAction, AppEnvironment> { state, action, environment in
  switch action {

  case let .app(.filterPicked(filter)) where state.step == .filters:
    state.placeholderApp.filter = filter
    return .none

  case let .app(action) where state.step == .todos:
    switch action {
    case .sortCompletedTodos,
         .todo(id: _, action: .checkBoxToggled):
      return appReducer
        .run(
          &state.placeholderApp,
          action,
          AppEnvironment(
            analytics: .onboarding(environment.analytics),
            mainQueue: environment.mainQueue,
            uuid: environment.uuid
          )
        )
        .map(OnboardingAction.app)

    default:
      return .none
    }

//    state.placeholderApp.todos[id: id]?.isComplete.toggle()
//    state.placeholderApp.todos.sortCompleted()
//    return .none

  case .app:
    return .none

  case .nextButtonTapped:
    state.step = state.step?.next
    return .none

  case .previousButtonTapped:
    state.step = state.step?.previous
    return .none

  case .skipButtonTapped:
    state.step = nil
    return .none
  }
}

struct OnboardingStepEnvironmentKey: EnvironmentKey {
  static var defaultValue: OnboardingStep? = nil
}
extension EnvironmentValues {
  var onboardingStep: OnboardingStep? {
    get { self[OnboardingStepEnvironmentKey.self] }
    set { self[OnboardingStepEnvironmentKey.self] = newValue }
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

struct OnboardingView: View {
//  @State var step: OnboardingStep? = .actions
  let onboardingStore: Store<OnboardingState, OnboardingAction>
  let store: Store<AppState, AppAction>

  var body: some View {
    WithViewStore(self.onboardingStore) { onboardingViewStore in
    if let step = onboardingViewStore.step {
      ZStack {
        AppView(
          store: self.onboardingStore.scope(
            state: \.placeholderApp,
            action: OnboardingAction.app
          )
//          store: Store(
//            initialState: AppState(todos: .mock),
//            reducer: .empty,
//            environment: ()
//          )
        )
        .environment(\.onboardingStep, step)
        .redacted(reason: .placeholder)

        VStack {
          Spacer()

          HStack(alignment: .top) {
            Button(action: { onboardingViewStore.send(.previousButtonTapped) }) {
              Image(systemName: "chevron.left")
            }
            //            .disabled(tutorialViewStore.tutorialStep == .actions)
            .frame(width: 44, height: 44)
            .foregroundColor(.white)
            .background(Color.gray)
            .clipShape(Circle())
            .padding([.leading, .trailing])

            Spacer()

            VStack {
              switch step {
              case .actions:
                Text("Use the navbar actions to mass delete todos, clear all your completed todos, or add a new one.")
              case .filters:
                Text("Use the filters bar to change what todos are currently displayed to you. Try changing a filter.")
              case .todos:
                Text("Here's your list of todos. You can check one off to complete it, or edit its title by tapping on the current title.")
              }
              Button("Skip") { onboardingViewStore.send(.skipButtonTapped) }
                .padding()
            }

            Spacer()
            Button(action: { onboardingViewStore.send(.nextButtonTapped) }) {
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
          .background(
            LinearGradient(
              gradient: .init(
                colors: [.init(white: 1, opacity: 0), .init(white: 0.8, opacity: 1)]
              ),
              startPoint: .top,
              endPoint: .bottom
            )
          )
        }
      }
    } else {
       AppView(store: self.store)
    }
    }
  }
}






struct AppView_Previews: PreviewProvider {
  static var previews: some View {
    AppView(
      store: Store(
        initialState: AppState(todos: .mock),
        reducer: .init { state, action, environment in
          switch action {
          case .filterPicked:
//            state.filter = filter
//            return .none
            return appReducer.run(&state, action, environment)

          default:
            return .none
          }
        },
        environment:
          //()
          AppEnvironment(
//            analytics: AnalyticsClient(
//              track: { name, properties in }
//            ),
            analytics: .live,
            mainQueue: DispatchQueue.main.eraseToAnyScheduler(),
            uuid: UUID.init
          )
      )
    )
    .redacted(reason: .placeholder)
  }
}

struct OnboardingView_Previews: PreviewProvider {
  static var previews: some View {
    OnboardingView(
      onboardingStore: Store(
        initialState: .init(placeholderApp: AppState(todos: .mock), step: .actions),
        reducer: onboardingReducer,
        environment: .init(
          analytics: .live,
          mainQueue: DispatchQueue.main.eraseToAnyScheduler(),
          uuid: UUID.init
        )
      ),
      store: Store(
        initialState: .init(),
        reducer: appReducer,
        environment: .init(
          analytics: .live,
          mainQueue: DispatchQueue.main.eraseToAnyScheduler(),
          uuid: UUID.init
        )
      )
    )
  }
}
