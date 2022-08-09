import ComposableArchitecture

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

let appReducer = Reducer<AppState, AppAction, AppEnvironment>.combine(
  Reducer { state, action, environment in
    // Additional application logic that runs before the tabs
    .none
  },
  tabAReducer
    .pullback(state: \.tabA, action: /AppAction.tabA, environment: { _ in .init() }),
  tabBReducer
    .pullback(state: \.tabB, action: /AppAction.tabB, environment: { _ in .init() }),
  tabCReducer
    .pullback(state: \.tabC, action: /AppAction.tabC, environment: { _ in .init() }),
  Reducer { state, action, environment in
    // Additional application logic that runs after the tabs
    .none
  }
)

struct FeatureState {
  var modal: ModalState?
  var rows: IdentifiedArrayOf<RowState>
  // …
}
enum FeatureAction {
  case modal(ModalAction)
  case row(id: RowState.ID, RowAction)
  // …
}
struct FeatureEnvironment {}

struct RowState: Identifiable {
  let id = UUID()
}
enum RowAction {}
struct RowEnvironment {}
let rowReducer = Reducer<RowState, RowAction, RowEnvironment> { _, _, _ in .none }

struct ModalState {
}
enum ModalAction {}
struct ModalEnvironment {}
let modalReducer = Reducer<ModalState, ModalAction, ModalEnvironment> { _, _, _ in .none }

let featureReducer = Reducer<FeatureState, FeatureAction, FeatureEnvironment>.combine(
  Reducer { _, _, _ in
    // Main feature logic
    .none
  },

  modalReducer
    .optional()
    .pullback(state: \.modal, action: /FeatureAction.modal, environment: { _ in .init() }),

  rowReducer
    .forEach(state: \.rows, action: /FeatureAction.row, environment: { _ in .init() })
)
