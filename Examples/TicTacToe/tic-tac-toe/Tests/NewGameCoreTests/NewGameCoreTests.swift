import ComposableArchitecture
import GameCore
import NewGameCore
import XCTest

final class NewGameCoreTests: XCTestCase {
  func testFlow_NewGame_Integration() async {
    let store = await TestStore(initialState: NewGame.State()) {
      NewGame()
    }
    await store.send(\.binding.oPlayerName, "Blob Sr.") {
      $0.oPlayerName = "Blob Sr."
    }
    await store.send(\.binding.xPlayerName, "Blob Jr.") {
      $0.xPlayerName = "Blob Jr."
    }
    await store.send(.letsPlayButtonTapped) {
      $0.game = Game.State(oPlayerName: "Blob Sr.", xPlayerName: "Blob Jr.")
    }
    await store.send(\.game.cellTapped, (row: 0, column: 0)) {
      $0.game!.board[0][0] = .x
      $0.game!.currentPlayer = .o
    }
    await store.send(\.game.quitButtonTapped)
    await store.receive(\.game.dismiss) {
      $0.game = nil
    }
    await store.send(.letsPlayButtonTapped) {
      $0.game = Game.State(oPlayerName: "Blob Sr.", xPlayerName: "Blob Jr.")
    }
    await store.send(\.game.dismiss) {
      $0.game = nil
    }
    await store.send(.logoutButtonTapped)
  }
}
