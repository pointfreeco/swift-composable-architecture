import ComposableArchitecture
import GameCore
import NewGameCore
import XCTest

class NewGameCoreTests: XCTestCase {
  let store = TestStore(
    initialState: NewGameState(),
    reducer: newGameReducer,
    environment: NewGameEnvironment()
  )

  func testFlow_NewGame_Integration() {
    self.store.assert(
      .send(.oPlayerNameChanged("Blob Sr.")) {
        $0.oPlayerName = "Blob Sr."
      },
      .send(.xPlayerNameChanged("Blob Jr.")) {
        $0.xPlayerName = "Blob Jr."
      },
      .send(.letsPlayButtonTapped) {
        $0.game = GameState(oPlayerName: "Blob Sr.", xPlayerName: "Blob Jr.")
      },
      .send(.game(.cellTapped(row: 0, column: 0))) {
        $0.game!.board[0][0] = .x
        $0.game!.currentPlayer = .o
      },
      .send(.game(.quitButtonTapped)) {
        $0.game = nil
      },
      .send(.letsPlayButtonTapped) {
        $0.game = GameState(oPlayerName: "Blob Sr.", xPlayerName: "Blob Jr.")
      },
      .send(.gameDismissed) {
        $0.game = nil
      },
      .send(.logoutButtonTapped)
    )
  }
}
