import AppCore
import ComposableArchitecture
import LoginSwiftUI
import NewGameSwiftUI
import SwiftUI
import TicTacToeCommon

public struct AppView: View {
  let store: Store<AppState, AppAction>

  public init(store: Store<AppState, AppAction>) {
    self.store = store
  }

  public var body: some View {
    SwitchStore(self.store) {
//      CaseLet(state: /AppState.login, action: AppAction.login) { loginStore in
//        NavigationView {
//          LoginView(store: loginStore)
//        }
//        .navigationViewStyle(StackNavigationViewStyle())
//      }

      CaseLet(state: /AppState.newGame, action: AppAction.newGame) { newGame in
        NavigationView {
          NewGameView(store: newGame)
        }
        .navigationViewStyle(StackNavigationViewStyle())
      }
    }
  }
}
