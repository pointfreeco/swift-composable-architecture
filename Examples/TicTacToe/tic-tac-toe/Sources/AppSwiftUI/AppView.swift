import AppCore
import ComposableArchitecture
import GameSwiftUI
import LoginSwiftUI
import NewGameSwiftUI
import SwiftUI
import TwoFactorSwiftUI

public struct AppView: View {
  let store: StoreOf<AppReducer>

  public init(store: StoreOf<AppReducer>) {
    self.store = store
  }

  public var body: some View {
    NavigationStackStore(store: self.store) {
      LoginView(
        store: self.store.scope(state: \.login, action: AppReducer.Action.login)
      )
        .navigationDestination(store: self.store) {
          DestinationStore(
            state: CasePath(AppReducer.State.Route.game).extract(from:),
            action: AppReducer.Action.Route.game,
            content: GameView.init(store:)
          )
          DestinationStore(
            state: CasePath(AppReducer.State.Route.newGame).extract(from:),
            action: AppReducer.Action.Route.newGame,
            content: NewGameView.init(store:)
          )
          DestinationStore(
            state: CasePath(AppReducer.State.Route.twoFactor).extract(from:),
            action: AppReducer.Action.Route.twoFactor,
            content: TwoFactorView.init(store:)
          )
        }
    }
  }
}
