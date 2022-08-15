import ComposableArchitecture
import GameCore
import NewGameCore
import XCTest

@MainActor
final class NewGameCoreTests: XCTestCase {
  let store = TestStore(
    initialState: NewGameState(),
    reducer: newGameReducer,
    environment: NewGameEnvironment()
  )

  func testFlow_NewGame_Integration() async {
    await self.store.send(.oPlayerNameChanged("Blob Sr.")) {
      $0.oPlayerName = "Blob Sr."
    }
    await self.store.send(.xPlayerNameChanged("Blob Jr.")) {
      $0.xPlayerName = "Blob Jr."
    }
    await self.store.send(.letsPlayButtonTapped) {
      $0.game = GameState(oPlayerName: "Blob Sr.", xPlayerName: "Blob Jr.")
    }
    await self.store.send(.game(.cellTapped(row: 0, column: 0))) {
      $0.game!.board[0][0] = .x
      $0.game!.currentPlayer = .o
    }
    await self.store.send(.game(.quitButtonTapped)) {
      $0.game = nil
    }
    await self.store.send(.letsPlayButtonTapped) {
      $0.game = GameState(oPlayerName: "Blob Sr.", xPlayerName: "Blob Jr.")
    }
    await self.store.send(.gameDismissed) {
      $0.game = nil
    }
    await self.store.send(.logoutButtonTapped)
  }
}
