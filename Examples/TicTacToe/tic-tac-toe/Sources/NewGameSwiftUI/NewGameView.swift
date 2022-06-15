import ComposableArchitecture
import NewGameCore
import SwiftUI

public struct NewGameView: View {
  @Environment(\.dismiss) var dismiss
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
    case oPlayerNameChanged(String)
    case xPlayerNameChanged(String)
  }

  public init(store: StoreOf<NewGame>) {
    self.store = store
  }

  public var body: some View {
    WithViewStore(self.store.scope(state: ViewState.init, action: NewGame.Action.init)) {
      viewStore in
      Form {
        Section {
          TextField(
            "Blob Sr.",
            text: viewStore.binding(get: \.xPlayerName, send: ViewAction.xPlayerNameChanged)
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
            text: viewStore.binding(get: \.oPlayerName, send: ViewAction.oPlayerNameChanged)
          )
          .autocapitalization(.words)
          .disableAutocorrection(true)
          .textContentType(.name)
        } header: {
          Text("O Player Name")
        }

        Button {
          viewStore.send(.letsPlayButtonTapped)
        } label: {
          Text("Let's play!")
        }
        .disabled(viewStore.isLetsPlayButtonDisabled)
      }
      .navigationBarTitle("New Game")
      .navigationBarBackButtonHidden(true)
      .navigationBarItems(leading: Button("Logout") { self.dismiss() })
    }
  }
}

extension NewGame.Action {
  init(action: NewGameView.ViewAction) {
    switch action {
    case .letsPlayButtonTapped:
      self = .letsPlayButtonTapped
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
          initialState: .init(),
          reducer: NewGame()
        )
      )
    }
  }
}
