import ComposableArchitecture
import GameCore
import GameSwiftUI
import NewGameCore
import SwiftUI
import TicTacToeCommon

public struct NewGameView: View {
  struct ViewState: Equatable {
    var isGameActive: Bool
    var isLetsPlayButtonDisabled: Bool
    var oPlayerName: String
    var xPlayerName: String
  }

  enum ViewAction {
    case gameDismissed
    case letsPlayButtonTapped
    case logoutButtonTapped
    case oPlayerNameChanged(String)
    case xPlayerNameChanged(String)
  }

  let store: Store<NewGameState, NewGameAction>

  public init(store: Store<NewGameState, NewGameAction>) {
    self.store = store
  }

  public var body: some View {
    WithViewStore(self.store.scope(state: { $0.view }, action: NewGameAction.view)) { viewStore in
      VStack {
        Form {
          Section(header: Text("X Player Name")) {
            TextField(
              "Blob Sr.",
              text: viewStore.binding(get: { $0.xPlayerName }, send: ViewAction.xPlayerNameChanged)
            )
            .autocapitalization(.words)
            .disableAutocorrection(true)
            .textContentType(.name)
          }
          Section(header: Text("O Player Name")) {
            TextField(
              "Blob Jr.",
              text: viewStore.binding(get: { $0.oPlayerName }, send: ViewAction.oPlayerNameChanged)
            )
            .autocapitalization(.words)
            .disableAutocorrection(true)
            .textContentType(.name)
          }
          Section {
            NavigationLink(
              destination: IfLetStore(
                self.store.scope(state: { $0.game }, action: NewGameAction.game),
                then: GameView.init(store:)
              ),
              isActive: viewStore.binding(
                get: { $0.isGameActive },
                send: { $0 ? .letsPlayButtonTapped : .gameDismissed }
              )
            ) {
              Text("Let's play!")
            }
            .disabled(viewStore.isLetsPlayButtonDisabled)
          }
        }
      }
      .navigationBarTitle("New Game")
      .navigationBarItems(trailing: Button("Logout") { viewStore.send(.logoutButtonTapped) })
    }
  }
}

extension NewGameState {
  var view: NewGameView.ViewState {
    NewGameView.ViewState(
      isGameActive: self.game != nil,
      isLetsPlayButtonDisabled: self.oPlayerName.isEmpty || self.xPlayerName.isEmpty,
      oPlayerName: self.oPlayerName,
      xPlayerName: self.xPlayerName
    )
  }
}

extension NewGameAction {
  static func view(_ viewAction: NewGameView.ViewAction) -> Self {
    switch viewAction {
    case .gameDismissed:
      return .gameDismissed
    case .letsPlayButtonTapped:
      return .letsPlayButtonTapped
    case .logoutButtonTapped:
      return .logoutButtonTapped
    case let .oPlayerNameChanged(name):
      return .oPlayerNameChanged(name)
    case let .xPlayerNameChanged(name):
      return .xPlayerNameChanged(name)
    }
  }
}

struct NewGame_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      NewGameView(
        store: Store(
          initialState: NewGameState(),
          reducer: newGameReducer,
          environment: NewGameEnvironment()
        )
      )
    }
  }
}
