import ComposableArchitecture
import GameCore
import XCTest

class GameSwiftUITests: XCTestCase {
  let store = TestStore(
    initialState: GameState(
      oPlayerName: "Blob Jr.",
      xPlayerName: "Blob Sr."
    ),
    reducer: gameReducer,
    environment: GameEnvironment()
  )

  func testFlow_Winner_Quit() {
    self.store.assert(
      .send(.cellTapped(row: 0, column: 0)) {
        $0.board[0][0] = .x
        $0.currentPlayer = .o
      },
      .send(.cellTapped(row: 2, column: 1)) {
        $0.board[2][1] = .o
        $0.currentPlayer = .x
      },
      .send(.cellTapped(row: 1, column: 0)) {
        $0.board[1][0] = .x
        $0.currentPlayer = .o
      },
      .send(.cellTapped(row: 1, column: 1)) {
        $0.board[1][1] = .o
        $0.currentPlayer = .x
      },
      .send(.cellTapped(row: 2, column: 0)) {
        $0.board[2][0] = .x
      },
      .send(.quitButtonTapped)
    )
  }

  func testFlow_Tie() {
    self.store.assert(
      .send(.cellTapped(row: 0, column: 0)) {
        $0.board[0][0] = .x
        $0.currentPlayer = .o
      },
      .send(.cellTapped(row: 2, column: 2)) {
        $0.board[2][2] = .o
        $0.currentPlayer = .x
      },
      .send(.cellTapped(row: 1, column: 0)) {
        $0.board[1][0] = .x
        $0.currentPlayer = .o
      },
      .send(.cellTapped(row: 2, column: 0)) {
        $0.board[2][0] = .o
        $0.currentPlayer = .x
      },
      .send(.cellTapped(row: 2, column: 1)) {
        $0.board[2][1] = .x
        $0.currentPlayer = .o
      },
      .send(.cellTapped(row: 1, column: 2)) {
        $0.board[1][2] = .o
        $0.currentPlayer = .x
      },
      .send(.cellTapped(row: 0, column: 2)) {
        $0.board[0][2] = .x
        $0.currentPlayer = .o
      },
      .send(.cellTapped(row: 0, column: 1)) {
        $0.board[0][1] = .o
        $0.currentPlayer = .x
      },
      .send(.cellTapped(row: 1, column: 1)) {
        $0.board[1][1] = .x
        $0.currentPlayer = .o
      },
      .send(.playAgainButtonTapped) {
        $0 = GameState(oPlayerName: "Blob Jr.", xPlayerName: "Blob Sr.")
      }
    )
  }
}
