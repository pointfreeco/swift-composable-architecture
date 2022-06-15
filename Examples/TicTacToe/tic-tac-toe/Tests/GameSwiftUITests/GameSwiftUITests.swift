import ComposableArchitecture
import GameCore
import XCTest

@testable import GameSwiftUI

class GameSwiftUITests: XCTestCase {
  let store = Store(
    initialState: GameState(
      oPlayerName: "Blob Jr.",
      xPlayerName: "Blob Sr."
    ),
    reducer: gameReducer,
    environment: GameEnvironment()
  )
  var viewStore: ViewStore<GameView.ViewState, GameAction> {
    ViewStore(store.scope(state: GameView.ViewState.init))
  }

  func testFlow_Winner_Quit() {
    self.viewStore.send(.cellTapped(row: 0, column: 0))
    XCTAssertNoDifference(
      .init(
        board: [["❌", "", ""], ["", "", ""], ["", "", ""]],
        isGameDisabled: false,
        isPlayAgainButtonVisible: false,
        title: "Blob Jr., place your ⭕️"
      ),
      self.viewStore.state
    )
    XCTAssertEqual("Blob Jr., place your ⭕️", self.viewStore.title)

    self.viewStore.send(.cellTapped(row: 2, column: 1))
    XCTAssertEqual("⭕️", self.viewStore.board[2][1])
    XCTAssertEqual("Blob Sr., place your ❌", self.viewStore.title)

    self.viewStore.send(.cellTapped(row: 1, column: 0))
    self.viewStore.send(.cellTapped(row: 1, column: 1))

    self.viewStore.send(.cellTapped(row: 2, column: 0))
    XCTAssertEqual(true, self.viewStore.isGameDisabled)
    XCTAssertEqual(true, self.viewStore.isPlayAgainButtonVisible)
    XCTAssertEqual("Winner! Congrats Blob Sr.!", self.viewStore.title)
  }

  func testFlow_Tie() {
    self.viewStore.send(.cellTapped(row: 0, column: 0))
    self.viewStore.send(.cellTapped(row: 2, column: 2))
    self.viewStore.send(.cellTapped(row: 1, column: 0))
    self.viewStore.send(.cellTapped(row: 2, column: 0))
    self.viewStore.send(.cellTapped(row: 2, column: 1))
    self.viewStore.send(.cellTapped(row: 1, column: 2))
    self.viewStore.send(.cellTapped(row: 0, column: 2))
    self.viewStore.send(.cellTapped(row: 0, column: 1))
    self.viewStore.send(.cellTapped(row: 1, column: 1))
    XCTAssertEqual(true, self.viewStore.isGameDisabled)
    XCTAssertEqual(true, self.viewStore.isPlayAgainButtonVisible)
    XCTAssertEqual("Tied game!", self.viewStore.title)

    self.viewStore.send(.playAgainButtonTapped)
    XCTAssertNoDifference(
      .init(state: GameState(oPlayerName: "Blob Jr.", xPlayerName: "Blob Sr.")),
      self.viewStore.state
    )
  }
}
