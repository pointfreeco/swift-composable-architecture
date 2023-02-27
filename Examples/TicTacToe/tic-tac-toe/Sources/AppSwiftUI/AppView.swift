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
    SwitchStore(self.store) {
      CaseLet(state: /TicTacToe.State.login, action: TicTacToe.Action.login) { store in
        NavigationStack {
          LoginView(store: store)
        }
      }
      CaseLet(state: /TicTacToe.State.newGame, action: TicTacToe.Action.newGame) { store in
        NavigationStack {
          NewGameView(store: store)
        }
      }
    }
  }
}
