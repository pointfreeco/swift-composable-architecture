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
    switch store.case {
    case let .login(store):
      NavigationStack {
        LoginView(store: store)
      }
    case let .newGame(store):
      NavigationStack {
        NewGameView(store: store)
      }
    }
  }
}
