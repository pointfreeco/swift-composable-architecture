import ComposableArchitecture
import GameCore
import GameSwiftUI
import NewGameCore
import SwiftUI

public struct NewGameView: View {
  @State var store: StoreOf<NewGame>

  public init(store: StoreOf<NewGame>) {
    self.store = store
  }

  public var body: some View {
    Form {
      Section {
        TextField("Blob Sr.", text: self.$store.xPlayerName)
          .autocapitalization(.words)
          .disableAutocorrection(true)
          .textContentType(.name)
      } header: {
        Text("X Player Name")
      }

      Section {
        TextField("Blob Jr.", text: self.$store.oPlayerName)
          .autocapitalization(.words)
          .disableAutocorrection(true)
          .textContentType(.name)
      } header: {
        Text("O Player Name")
      }

      Button("Let's play!") {
        self.store.send(.letsPlayButtonTapped)
      }
      .disabled(self.store.isLetsPlayButtonDisabled)
    }
    .navigationTitle("New Game")
    .navigationBarItems(trailing: Button("Logout") { self.store.send(.logoutButtonTapped) })
    .navigationDestination(item: self.$store.scope(state: \.game, action: \.game)) { store in
      GameView(store: store)
    }
  }
}

fileprivate extension NewGame.State {
  var isLetsPlayButtonDisabled: Bool { self.oPlayerName.isEmpty || self.xPlayerName.isEmpty }
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
