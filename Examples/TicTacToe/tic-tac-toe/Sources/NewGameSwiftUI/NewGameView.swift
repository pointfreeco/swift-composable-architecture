import ComposableArchitecture
import GameCore
import GameSwiftUI
import NewGameCore
import SwiftUI

extension NewGame.State {
  var isLetsPlayButtonDisabled: Bool {
    self.oPlayerName.isEmpty || self.xPlayerName.isEmpty
  }
}

@WithViewStore(for: NewGame.self)
public struct NewGameView: View {
  let store: StoreOf<NewGame>

  public init(store: StoreOf<NewGame>) {
    self.store = store
  }

  public var body: some View {
    Form {
      Section {
        TextField(
          "Blob Sr.",
          text: store.binding(get: \.xPlayerName, send: { .view(.xPlayerNameChanged($0)) })
        )
        .autocapitalization(.words)
        .disableAutocorrection(true)
        .textContentType(.name)
      } header: {
        Text("X Player Name")
      }

      Section {
        TextField(
          "Blob Jr.",
          text: store.binding(get: \.oPlayerName, send: { .view(.oPlayerNameChanged($0)) })
        )
        .autocapitalization(.words)
        .disableAutocorrection(true)
        .textContentType(.name)
      } header: {
        Text("O Player Name")
      }

      Button("Let's play!") {
        send(.letsPlayButtonTapped)
      }
      .disabled(store.isLetsPlayButtonDisabled)
    }
    .navigationTitle("New Game")
    .navigationBarItems(trailing: Button("Logout") { send(.logoutButtonTapped) })
    .navigationDestination(
      store: self.store.scope(state: \.$game, action: { .game($0) }),
      destination: GameView.init
    )
  }
}

struct NewGame_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      NewGameView(
        store: Store(initialState: NewGame.State()) {
          NewGame()
        }
      )
    }
  }
}
