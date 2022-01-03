import ComposableArchitecture
import GameCore
import GameSwiftUI
import NewGameCore
import SwiftUI

public struct NewGameView: View {
  let store: Store<NewGameState, NewGameAction>

  struct ViewState: Equatable {
    var isGameActive: Bool
    var isLetsPlayButtonDisabled: Bool
    var oPlayerName: String
    var xPlayerName: String

    init(state: NewGameState) {
      self.isGameActive = state.game != nil
      self.isLetsPlayButtonDisabled = state.oPlayerName.isEmpty || state.xPlayerName.isEmpty
      self.oPlayerName = state.oPlayerName
      self.xPlayerName = state.xPlayerName
    }
  }

  enum ViewAction {
    case gameDismissed
    case letsPlayButtonTapped
    case logoutButtonTapped
    case oPlayerNameChanged(String)
    case xPlayerNameChanged(String)
  }

  public init(store: Store<NewGameState, NewGameAction>) {
    self.store = store
  }

  public var body: some View {
    WithViewStore(self.store.scope(state: ViewState.init, action: NewGameAction.init)) {
      viewStore in
      ScrollView {
        VStack(spacing: 16) {
          VStack(alignment: .leading) {
            Text("X Player Name")
            TextField(
              "Blob Sr.",
              text: viewStore.binding(get: \.xPlayerName, send: ViewAction.xPlayerNameChanged)
            )
            .autocapitalization(.words)
            .disableAutocorrection(true)
            .textContentType(.name)
            .textFieldStyle(.roundedBorder)
          }

          VStack(alignment: .leading) {
            Text("O Player Name")
            TextField(
              "Blob Jr.",
              text: viewStore.binding(get: \.oPlayerName, send: ViewAction.oPlayerNameChanged)
            )
            .autocapitalization(.words)
            .disableAutocorrection(true)
            .textContentType(.name)
            .textFieldStyle(.roundedBorder)
          }

          NavigationLink(
            destination: IfLetStore(
              self.store.scope(state: \.game, action: NewGameAction.game),
              then: GameView.init(store:)
            ),
            isActive: viewStore.binding(
              get: \.isGameActive,
              send: { $0 ? .letsPlayButtonTapped : .gameDismissed }
            )
          ) {
            Text("Let's play!")
          }
          .disabled(viewStore.isLetsPlayButtonDisabled)
        }
        .padding(.horizontal)
      }
      .navigationBarTitle("New Game")
      .navigationBarItems(trailing: Button("Logout") { viewStore.send(.logoutButtonTapped) })
    }
  }
}

extension NewGameAction {
  init(action: NewGameView.ViewAction) {
    switch action {
    case .gameDismissed:
      self = .gameDismissed
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
