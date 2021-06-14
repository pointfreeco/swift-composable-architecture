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

  @ViewBuilder public var body: some View {
    SwitchStore(self.store) {
      CaseLet(state: /AppState.login, action: AppAction.login) { store in
        NavigationView {
          LoginView(store: store)
        }
        .navigationViewStyle(StackNavigationViewStyle())
      }
      CaseLet(state: /AppState.newGame, action: AppAction.newGame) { store in
        NavigationView {
          NewGameView(store: store)
        }
        .navigationViewStyle(StackNavigationViewStyle())
      }
    }
  }
}
