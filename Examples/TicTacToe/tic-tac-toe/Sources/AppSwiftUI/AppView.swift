import AppCore
import ComposableArchitecture
import LoginSwiftUI
import NewGameSwiftUI
import SwiftUI

public struct AppView: View {
  let store: Store<AppState, AppAction>

  public init(store: Store<AppState, AppAction>) {
    self.store = store
  }

  public var body: some View {
    SwitchStore(self.store) {
      CaseLet(state: /AppState.login, action: AppAction.login) { store in
        NavigationView {
          LoginView(store: store)
        }
        .navigationViewStyle(.stack)
      }
      CaseLet(state: /AppState.newGame, action: AppAction.newGame) { store in
        NavigationView {
          NewGameView(store: store)
        }
        .navigationViewStyle(.stack)
      }
    }
  }
}
