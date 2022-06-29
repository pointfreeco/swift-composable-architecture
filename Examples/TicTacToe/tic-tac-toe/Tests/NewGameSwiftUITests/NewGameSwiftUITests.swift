import ComposableArchitecture
import NewGameCore
import XCTest

@testable import NewGameSwiftUI

class NewGameSwiftUITests: XCTestCase {
  let store = TestStore(
    initialState: NewGame.State(),
    reducer: NewGame()
  )
  .scope(state: NewGameView.ViewState.init, action: NewGame.Action.init)

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
