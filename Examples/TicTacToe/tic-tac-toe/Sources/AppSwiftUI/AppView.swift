import AppCore
import ComposableArchitecture
import LoginSwiftUI
import NewGameSwiftUI
import SwiftUI

public struct AppView: View {
  let store: StoreOf<AppReducer>

  public init(store: StoreOf<AppReducer>) {
    self.store = store
  }

  public var body: some View {
    SwitchStore(self.store) {
      CaseLet(state: /AppReducer.State.login, action: AppReducer.Action.login) { store in
        NavigationView {
          LoginView(store: store)
        }
        .navigationViewStyle(.stack)
      }
      CaseLet(state: /AppReducer.State.newGame, action: AppReducer.Action.newGame) { store in
        NavigationView {
          NewGameView(store: store)
        }
        .navigationViewStyle(.stack)
      }
    }
  }
}
