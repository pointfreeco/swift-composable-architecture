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
  .scope(state: NewGameView.ViewState.init, action: NewGameAction.init)

  func testNewGame() {
    self.store.send(.xPlayerNameChanged("Blob Sr.")) {
      $0.xPlayerName = "Blob Sr."
    }
    self.store.send(.oPlayerNameChanged("Blob Jr.")) {
      $0.oPlayerName = "Blob Jr."
      $0.isLetsPlayButtonDisabled = false
    }
    self.store.send(.letsPlayButtonTapped) {
      $0.isGameActive = true
    }
    self.store.send(.gameDismissed) {
      $0.isGameActive = false
    }
    self.store.send(.logoutButtonTapped)
  }
}
