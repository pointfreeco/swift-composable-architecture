import ComposableArchitecture
import GameCore
import NewGameCore
import XCTest

@MainActor
final class NewGameCoreTests: XCTestCase {
  let store = TestStore(initialState: NewGame.State()) {
    NewGame()
  }

  func testFlow_NewGame_Integration() async {
    await self.store.send(.set(\.oPlayerName, "Blob Sr.")) {
      $0.oPlayerName = "Blob Sr."
    }
    await self.store.send(.set(\.xPlayerName, "Blob Jr.")) {
      $0.xPlayerName = "Blob Jr."
    }
    await self.store.send(.letsPlayButtonTapped) {
      $0.game = Game.State(oPlayerName: "Blob Sr.", xPlayerName: "Blob Jr.")
    }
    await self.store.send(.game(.presented(.cellTapped(row: 0, column: 0)))) {
      $0.game!.board[0][0] = .x
      $0.game!.currentPlayer = .o
    }
    await self.store.send(.game(.presented(.quitButtonTapped)))
    await self.store.receive(\.game.dismiss) {
      $0.game = nil
    }
    await self.store.send(.letsPlayButtonTapped) {
      $0.game = Game.State(oPlayerName: "Blob Sr.", xPlayerName: "Blob Jr.")
    }
    await self.store.send(.game(.dismiss)) {
      $0.game = nil
    }
    await self.store.send(.logoutButtonTapped)
  }
}
