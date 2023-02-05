import ComposableArchitecture
import GameCore
import XCTest

@testable import GameSwiftUI

@MainActor
final class GameSwiftUITests: XCTestCase {
  let store = TestStore(
    initialState: Game.State(
      oPlayerName: "Blob Jr.",
      xPlayerName: "Blob Sr."
    ),
    reducer: Game(),
    observe: GameView.ViewState.init,
    send: { $0 }
  )

  func testFlow_Winner_Quit() async {
    await self.store.send(.cellTapped(row: 0, column: 0)) {
      $0.board[0][0] = "❌"
      $0.title = "Blob Jr., place your ⭕️"
    }
    await self.store.send(.cellTapped(row: 2, column: 1)) {
      $0.board[2][1] = "⭕️"
      $0.title = "Blob Sr., place your ❌"
    }
    await self.store.send(.cellTapped(row: 1, column: 0)) {
      $0.board[1][0] = "❌"
      $0.title = "Blob Jr., place your ⭕️"
    }
    await self.store.send(.cellTapped(row: 1, column: 1)) {
      $0.board[1][1] = "⭕️"
      $0.title = "Blob Sr., place your ❌"
    }
    await self.store.send(.cellTapped(row: 2, column: 0)) {
      $0.board[2][0] = "❌"
      $0.isGameDisabled = true
      $0.isPlayAgainButtonVisible = true
      $0.title = "Winner! Congrats Blob Sr.!"
    }
    await self.store.send(.quitButtonTapped)
  }

  func testFlow_Tie() async {
    await self.store.send(.cellTapped(row: 0, column: 0)) {
      $0.board[0][0] = "❌"
      $0.title = "Blob Jr., place your ⭕️"
    }
    await self.store.send(.cellTapped(row: 2, column: 2)) {
      $0.board[2][2] = "⭕️"
      $0.title = "Blob Sr., place your ❌"
    }
    await self.store.send(.cellTapped(row: 1, column: 0)) {
      $0.board[1][0] = "❌"
      $0.title = "Blob Jr., place your ⭕️"
    }
    await self.store.send(.cellTapped(row: 2, column: 0)) {
      $0.board[2][0] = "⭕️"
      $0.title = "Blob Sr., place your ❌"
    }
    await self.store.send(.cellTapped(row: 2, column: 1)) {
      $0.board[2][1] = "❌"
      $0.title = "Blob Jr., place your ⭕️"
    }
    await self.store.send(.cellTapped(row: 1, column: 2)) {
      $0.board[1][2] = "⭕️"
      $0.title = "Blob Sr., place your ❌"
    }
    await self.store.send(.cellTapped(row: 0, column: 2)) {
      $0.board[0][2] = "❌"
      $0.title = "Blob Jr., place your ⭕️"
    }
    await self.store.send(.cellTapped(row: 0, column: 1)) {
      $0.board[0][1] = "⭕️"
      $0.title = "Blob Sr., place your ❌"
    }
    await self.store.send(.cellTapped(row: 1, column: 1)) {
      $0.board[1][1] = "❌"
      $0.isGameDisabled = true
      $0.isPlayAgainButtonVisible = true
      $0.title = "Tied game!"
    }
    await self.store.send(.playAgainButtonTapped) {
      $0 = GameView.ViewState(state: Game.State(oPlayerName: "Blob Jr.", xPlayerName: "Blob Sr."))
    }
  }
}
