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
    IfLetStore(
      self.store.scope(
        state: { (/AppState.login).extract(from: $0)  },
        action: AppAction.login
      ),
      then: { store in
        NavigationView {
          LoginView(store: store)
        }
      }
    )

    IfLetStore(
      self.store.scope(
        state: { (/AppState.newGame).extract(from: $0)  },
        action: AppAction.newGame
      ),
      then: { store in
        NavigationView {
          NewGameView(store: store)
        }
      }
    )

//    SwitchStore(self.store) {
//      CaseLet(state: /AppState.login, action: AppAction.login) { store in
//        NavigationView {
//          LoginView(store: store)
//        }
//      }
//      CaseLet(state: /AppState.newGame, action: AppAction.newGame) { store in
//        NavigationView {
//          NewGameView(store: store)
//        }
//      }
//    }
  }
}
