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


struct TabA: ReducerProtocol {
  struct State {}
  enum Action {}
  func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    .none
  }
}

struct TabB: ReducerProtocol {
  struct State {}
  enum Action {}
  func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    .none
  }
}

struct TabC: ReducerProtocol {
  struct State {}
  enum Action {}
  func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    .none
  }
}

struct AppReducer: ReducerProtocol {
//  func reduce(into state: inout State, action: Action) -> ComposableArchitecture.Effect<Action, Never> {
//    <#code#>
//  }

  struct State {
    var tabA: TabA.State
    var tabB: TabB.State
    var tabC: TabC.State
  }
  enum Action {
    case tabA(TabA.Action)
    case tabB(TabB.Action)
    case tabC(TabC.Action)
  }

  var body: some ReducerProtocol<State, Action> {
    Reduce { _, _ in
      .none
    }

    Scope(state: \.tabA, action: /Action.tabA) {
      TabA()
    }

    Scope(state: \.tabB, action: /Action.tabB) {
      TabB()
    }

    Scope(state: \.tabC, action: /Action.tabC) {
      TabC()
    }

    Reduce { _, _ in
      .none
    }
  }
}


import SwiftUI
struct SomeView: View {
  var body: VStack<TupleView<(Text, TextField<Text>, Button<Text>)>> {
    VStack {
      Text("Login")
      TextField("Email", text: .constant(""))
      Button("Go") {}
    }
  }
}

/*
 let appReducer: CombineReducer<
  CombineReducer<
    PullbackReducer<AppState, AppAction, TabA>,
    PullbackReducer<AppState, AppAction, TabB>
  >,
  PullbackReducer<AppState, AppAction, TabC>
 >
 */

/*
 CombineReducers(
   Counter(),
   Counter(),
   Counter()
 )
*/

//struct Combine3Reducers<R1, R2, R3>: ReducerProtocol {
//
//}
//struct Combine4Reducers<R1, R2, R3>: ReducerProtocol {
//
//}
//struct Combine5Reducers<R1, R2, R3>: ReducerProtocol {
//
//}
//
//Combine5Reducers(
//  Counter(),
//  Counter(),
//  Counter(),
//  Counter(),
//  Counter()
//)

/*

StartsWith("(")
  .take(Int.parser())
  .skip(StartsWith(","))
  .take(Prefix { $0 != ")")
  .skip(")")
  .map(User.init(id:name:))


Parse(User.init(id:name:)) {
  "("
  Int.parser()
  ","
  Prefix { $0 != ")" }
  ")"
}


 CombineReducers {
   Counter()
   Counter()
   Counter()
 }

 */

//struct CombineReducers<???>: ReducerProtocol {
//  let reducers: [???]
//}

/*
 let appReducer = CombineReducers(
   TabA()
     .pullback(state: \AppState.tabA, action: /AppAction.tabA),
   TabB()
     .pullback(state: \.tabB, action: /AppAction.tabB),
   TabC()
     .pullback(state: \.tabC, action: /AppAction.tabC)
 )
 */

//let appReducer = Reducer<_, _, AppEnvironment>.combine(
//  Reducer { _, _, _ in
//    // additional logic
//    .none
//  },
//  tabAReducer
//    .pullback(state: \.tabA, action: /AppAction.tabA, environment: { _ in .init() }),
//  tabBReducer
//    .pullback(state: \.tabB, action: /AppAction.tabB, environment: { _ in .init() }),
//  tabCReducer
//    .pullback(state: \AppState.tabC, action: /AppAction.tabC, environment: { _ in .init() }),
//  Reducer { _, _, _ in
//    // additional logic
//    .none
//  }
//)

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

import Combine

func somePublisher() {
  let x: some Publisher<Int, Never> = Just(1)
  x.map { $0 + 1 }
}
