import ComposableArchitecture
import NewGameCore
import XCTest

@testable import NewGameSwiftUI

class NewGameSwiftUITests: XCTestCase {
  let store = TestStore(
    initialState: NewGameState(),
    reducer: newGameReducer,
    environment: NewGameEnvironment()
  )
  .scope(state: { $0.view }, action: NewGameAction.view)

  func testNewGame() {
    self.store.assert(
      .send(.xPlayerNameChanged("Blob Sr.")) {
        $0.xPlayerName = "Blob Sr."
      },
      .send(.oPlayerNameChanged("Blob Jr.")) {
        $0.oPlayerName = "Blob Jr."
        $0.isLetsPlayButtonDisabled = false
      },
      .send(.letsPlayButtonTapped) {
        $0.isGameActive = true
      },
      .send(.gameDismissed) {
        $0.isGameActive = false
      },
      .send(.logoutButtonTapped)
    )
  }
}
