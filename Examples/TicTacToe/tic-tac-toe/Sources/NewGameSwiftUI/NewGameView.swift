import ComposableArchitecture
import GameCore
import GameSwiftUI
import NewGameCore
import SwiftUI

public struct NewGameView: View {
  let store: StoreOf<NewGame>

  struct ViewState: Equatable {
    var isLetsPlayButtonDisabled: Bool
    var oPlayerName: String
    var xPlayerName: String

    init(state: NewGame.State) {
      self.isLetsPlayButtonDisabled = state.oPlayerName.isEmpty || state.xPlayerName.isEmpty
      self.oPlayerName = state.oPlayerName
      self.xPlayerName = state.xPlayerName
    }
  }

  enum ViewAction {
    case letsPlayButtonTapped
    case logoutButtonTapped
    case oPlayerNameChanged(String)
    case xPlayerNameChanged(String)
  }

  public init(store: StoreOf<NewGame>) {
    self.store = store
  }

  public var body: some View {
    WithViewStore(self.store, observe: ViewState.init, send: NewGame.Action.init) { viewStore in
      Form {
        Section {
          TextField(
            "Blob Sr.",
            text: viewStore.binding(get: \.xPlayerName, send: { .xPlayerNameChanged($0) })
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
            text: viewStore.binding(get: \.oPlayerName, send: { .oPlayerNameChanged($0) })
          )
          .autocapitalization(.words)
          .disableAutocorrection(true)
          .textContentType(.name)
        } header: {
          Text("O Player Name")
        }

        Button("Let's play!") {
          viewStore.send(.letsPlayButtonTapped)
        }
        .disabled(viewStore.isLetsPlayButtonDisabled)
      }
      .navigationTitle("New Game")
      .navigationBarItems(trailing: Button("Logout") { viewStore.send(.logoutButtonTapped) })
      .navigationDestination(
        store: self.store.scope(state: \.$game, action: \.game),
        destination: GameView.init
      )
    }
  }
}

extension NewGame.Action {
  init(action: NewGameView.ViewAction) {
    switch action {
    case .letsPlayButtonTapped:
      self = .letsPlayButtonTapped
    case .logoutButtonTapped:
      self = .logoutButtonTapped
    case let .oPlayerNameChanged(name):
      self = .oPlayerNameChanged(name)
    case let .xPlayerNameChanged(name):
      self = .xPlayerNameChanged(name)
    }
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
