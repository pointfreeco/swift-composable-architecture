import ComposableArchitecture


struct RowState: Identifiable {
  let id = UUID()
}
enum RowAction {}
struct RowEnvironment {}
let rowReducer = Reducer<RowState, RowAction, RowEnvironment> { _, _, _ in .none }

struct ModalState {}
enum ModalAction {}
struct ModalEnvironment {}
let modalReducer = Reducer<ModalState, ModalAction, ModalEnvironment> { _, _, _ in
  .none
}

enum Feature {
  struct State {
    var modal: ModalState?
    var rows: IdentifiedArrayOf<RowState>
  }
  enum Action {
    case buttonTapped
    case otherButtonTapped
    case modal(ModalAction)
    case row(id: RowState.ID, action: RowAction)

    case sharedButtonLogic
  }
  struct Environment {
  }
  static let reducer = Reducer<
    State,
    Action,
    Environment
  >.combine(
    modalReducer
      .optional()
      .pullback(state: \.modal, action: /Action.modal, environment: { _ in .init() }),

    rowReducer
      .forEach(state: \.rows, action: /Action.row, environment: { _ in .init() }),

    Reducer { state, action, environment in
      switch action {
      case .buttonTapped:
        // Additional logic
        //return sharedButtonTapLogic(state: &state, environment: environment)
        //return state.sharedButtonTapLogic(environment: environment)
        return Effect(value: .sharedButtonLogic)
      case .otherButtonTapped:
        // Additional logic
        //return sharedButtonTapLogic(state: &state, environment: environment)
        //return state.sharedButtonTapLogic(environment: environment)
        return Effect(value: .sharedButtonLogic)

      case .sharedButtonLogic:
        // Do shared logic
        return .none

      case .modal:
        return .none

      case .row:
        return .none
      }
    }
  )

  private static func sharedButtonTapLogic(
    state: inout State,
    environment: Environment
  ) -> Effect<Action, Never> {
    .none
  }
}

extension Feature.State {
  fileprivate mutating func sharedButtonTapLogic(
    environment: Feature.Environment
  ) -> Effect<Feature.Action, Never> {
    .none
  }
}


struct TabAState {}
enum TabAAction {}
struct TabAEnvironment {}
let tabAReducer = Reducer<TabAState, TabAAction, TabAEnvironment> { _, _, _ in .none }

struct TabBState {}
enum TabBAction {}
struct TabBEnvironment {}
let tabBReducer = Reducer<TabBState, TabBAction, TabBEnvironment> { _, _, _ in .none }

struct TabCState {}
enum TabCAction {}
struct TabCEnvironment {}
let tabCReducer = Reducer<TabCState, TabCAction, TabCEnvironment> { _, _, _ in .none }


struct AppState {
  var tabA: TabAState
  var tabB: TabBState
  var tabC: TabCState
}
enum AppAction {
  case tabA(TabAAction)
  case tabB(TabBAction)
  case tabC(TabCAction)
}
enum AppEnvironment {}


let appReducer = Reducer<_, _, AppEnvironment>.combine(
  Reducer { _, _, _ in
    // additional logic
    .none
  },
  tabAReducer
    .pullback(state: \.tabA, action: /AppAction.tabA, environment: { _ in .init() }),
  tabBReducer
    .pullback(state: \.tabB, action: /AppAction.tabB, environment: { _ in .init() }),
  tabCReducer
    .pullback(state: \AppState.tabC, action: /AppAction.tabC, environment: { _ in .init() }),
  Reducer { _, _, _ in
    // additional logic
    .none
  }
)

/*
 Reducer1()
 Reducer2()
 Reducer3()



  Reducer { _, _, _ in
    // additional logic
    .none
  }

  Scope(state: \.tabA, action: /AppAction.tabA, environment: { _ in .init() }) {
    tabAReducer
  }

  Scope(state: \.tabB, action: /AppAction.tabB, environment: { _ in .init() }) {
    tabBReducer
  }

  Scope(state: \.tabC, action: /AppAction.tabC, environment: { _ in .init() }) {
    tabCReducer
  }

  Reducer { _, _, _ in
    // additional logic
    .none
  }



 Reducer { _, _, _ in
   // core feature logic
   .none
 }
 .ifLet(state: \.modal, action: /Action.modal, ...) {
   BeforeModal()
   Modal()
   AfterModal()
 }
 .forEach(state: \.rows, action: /Action.row, ...) {
   BeforeRow()
   Row()
   AfterRow()
 }
 */
