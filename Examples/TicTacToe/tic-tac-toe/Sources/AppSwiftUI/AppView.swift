import AppCore
import ComposableArchitecture
import LoginSwiftUI
import NewGameSwiftUI
import SwiftUI

public struct AppView: View {
  let store: StoreOf<TicTacToe>

  public init(store: StoreOf<TicTacToe>) {
    self.store = store
  }

  public var body: some View {
    SwitchStore(self.store) { state in
      switch state {
      case .login:
        CaseLet(/TicTacToe.State.login, action: TicTacToe.Action.login) { store in
          NavigationView {
            LoginView(store: store)
          }
        }
      case .newGame:
        CaseLet(/TicTacToe.State.newGame, action: TicTacToe.Action.newGame) { store in
          NavigationView {
            NewGameView(store: store)
          }
        }
      }
    }
    .navigationViewStyle(.stack)
  }
}
