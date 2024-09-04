import ComposableArchitecture
import GameCore
import GameSwiftUI
import NewGameCore
import SwiftUI

public struct NewGameView: View {
  @Bindable var store: StoreOf<NewGame>

  public init(store: StoreOf<NewGame>) {
    self.store = store
  }

  public var body: some View {
    Form {
      Section {
        TextField("Blob Sr.", text: $store.xPlayerName)
          .autocapitalization(.words)
          .disableAutocorrection(true)
          .textContentType(.name)
      } header: {
        Text("X Player Name")
      }

      Section {
        TextField("Blob Jr.", text: $store.oPlayerName)
          .autocapitalization(.words)
          .disableAutocorrection(true)
          .textContentType(.name)
      } header: {
        Text("O Player Name")
      }

      Button("Let's play!") {
        store.send(.letsPlayButtonTapped)
      }
      .disabled(store.isLetsPlayButtonDisabled)
    }
    .navigationTitle("New Game")
    .navigationBarItems(trailing: Button("Logout") { store.send(.logoutButtonTapped) })
    .navigationDestination(item: $store.scope(state: \.game, action: \.game)) { store in
      GameView(store: store)
    }
  }
}

extension NewGame.State {
  fileprivate var isLetsPlayButtonDisabled: Bool {
    self.oPlayerName.isEmpty || self.xPlayerName.isEmpty
  }
}

#Preview {
  NavigationStack {
    NewGameView(
      store: Store(initialState: NewGame.State()) {
        NewGame()
      }
    )
  }
}
