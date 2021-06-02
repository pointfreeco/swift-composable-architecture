import AppCore
import ComposableArchitecture
import LoginSwiftUI
import NewGameSwiftUI
import SwiftUI
import TicTacToeCommon

struct SwitchStore<State, Action, Content>: View where Content: View {
  let store: Store<State, Action>
  let content: () -> Content
  
  init(
    _ store: Store<State, Action>,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.store = store
    self.content = content
  }
  
  var body: some View {
    self.content()
  }
}

struct CaseLet<GlobalState, GlobalAction, LocalState, LocalAction, Content>: View
where Content: View {
  let store: Store<GlobalState, GlobalAction>
  let state: CasePath<GlobalState, LocalState>
  let action: (LocalAction) -> GlobalAction
  @ViewBuilder let content: (Store<LocalState, LocalAction>) -> Content
  
  var body: some View {
    IfLetStore(
      self.store.scope(state: state.extract(from:), action: action),
      then: self.content
    )
  }
}

public struct AppView: View {
  let store: Store<AppState, AppAction>

  public init(store: Store<AppState, AppAction>) {
    self.store = store
  }

  @ViewBuilder public var body: some View {
    SwitchStore(self.store) {
      CaseLet(
        store: self.store,
        state: /AppState.login,
        action: AppAction.login
      ) { loginStore in
        NavigationView {
          LoginView(store: loginStore)
        }
        .navigationViewStyle(StackNavigationViewStyle())
      }
      CaseLet(
        store: self.store,
        state: /AppState.newGame,
        action: AppAction.newGame
      ) { newGameStore in
        NavigationView {
          NewGameView(store: newGameStore)
        }
        .navigationViewStyle(StackNavigationViewStyle())
      }
    }
    
//    SwitchStore(self.store) {
//      CaseLet(state: /AppState.login, action: AppAction.login) { loginStore in
//        NavigationView {
//          LoginView(store: loginStore)
//        }
//        .navigationViewStyle(StackNavigationViewStyle())
//      }
//      CaseLet(state: /AppState.newGame, action: AppAction.newGame) { newGameStore in
//        NavigationView {
//          NewGameView(store: newGameStore)
//        }
//        .navigationViewStyle(StackNavigationViewStyle())
//      }
//    }
    
//    IfLetStore(
//      self.store.scope(
//        state: /AppState.login,
//        action: AppAction.login
//      )
//    ) { store in
//      NavigationView {
//        LoginView(store: store)
//      }
//      .navigationViewStyle(StackNavigationViewStyle())
//    }
//
//    IfLetStore(
//      self.store.scope(
//        state: /AppState.newGame,
//        action: AppAction.newGame
//      )
//    ) { store in
//      NavigationView {
//        NewGameView(store: store)
//      }
//      .navigationViewStyle(StackNavigationViewStyle())
//    }
  }
}
