import ComposableArchitecture
import GameCore
import XCTest

@MainActor
final class GameCoreTests: XCTestCase {
  let store = TestStore(
    initialState: Game.State(
      oPlayerName: "Blob Jr.",
      xPlayerName: "Blob Sr."
    )
  ) {
    Game()
  }

  func testFlow_Winner_Quit() async {
    await self.store.send(.cellTapped(row: 0, column: 0)) {
      $0.board[0][0] = .x
      $0.currentPlayer = .o
    }
    await self.store.send(.cellTapped(row: 2, column: 1)) {
      $0.board[2][1] = .o
      $0.currentPlayer = .x
    }
    await self.store.send(.cellTapped(row: 1, column: 0)) {
      $0.board[1][0] = .x
      $0.currentPlayer = .o
    }
    await self.store.send(.cellTapped(row: 1, column: 1)) {
      $0.board[1][1] = .o
      $0.currentPlayer = .x
    }
    await self.store.send(.cellTapped(row: 2, column: 0)) {
      $0.board[2][0] = .x
    }
  }

  func testFlow_Tie() async {
    await self.store.send(.cellTapped(row: 0, column: 0)) {
      $0.board[0][0] = .x
      $0.currentPlayer = .o
    }
    await self.store.send(.cellTapped(row: 2, column: 2)) {
      $0.board[2][2] = .o
      $0.currentPlayer = .x
    }
    await self.store.send(.cellTapped(row: 1, column: 0)) {
      $0.board[1][0] = .x
      $0.currentPlayer = .o
    }
    await self.store.send(.cellTapped(row: 2, column: 0)) {
      $0.board[2][0] = .o
      $0.currentPlayer = .x
    }
    await self.store.send(.cellTapped(row: 2, column: 1)) {
      $0.board[2][1] = .x
      $0.currentPlayer = .o
    }
    await self.store.send(.cellTapped(row: 1, column: 2)) {
      $0.board[1][2] = .o
      $0.currentPlayer = .x
    }
    await self.store.send(.cellTapped(row: 0, column: 2)) {
      $0.board[0][2] = .x
      $0.currentPlayer = .o
    }
    await self.store.send(.cellTapped(row: 0, column: 1)) {
      $0.board[0][1] = .o
      $0.currentPlayer = .x
    }
    await self.store.send(.cellTapped(row: 1, column: 1)) {
      $0.board[1][1] = .x
      $0.currentPlayer = .o
    }
    await self.store.send(.playAgainButtonTapped) {
      $0 = Game.State(oPlayerName: "Blob Jr.", xPlayerName: "Blob Sr.")
    }
  }
}
