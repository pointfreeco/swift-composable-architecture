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
    switch self.store.state {
    case .login:
      if let store = self.store.scope(state: \.login, action: \.login) {
        NavigationStack {
          LoginView(store: store)
        }
      }
    case .newGame:
      if let store = self.store.scope(state: \.newGame, action: \.newGame) {
        NavigationStack {
          NewGameView(store: store)
        }
      }
    }
  }
}
