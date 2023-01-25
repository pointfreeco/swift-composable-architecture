import ComposableArchitecture
import NewGameCore
import XCTest

@testable import NewGameSwiftUI

@MainActor
final class NewGameSwiftUITests: XCTestCase {
  let store = TestStore(
    initialState: NewGame.State(),
    reducer: NewGame(),
    observe: NewGameView.ViewState.init,
    send: NewGame.Action.init
  )

  func testNewGame() async {
    await self.store.send(.xPlayerNameChanged("Blob Sr.")) {
      $0.xPlayerName = "Blob Sr."
    }
    await self.store.send(.oPlayerNameChanged("Blob Jr.")) {
      $0.oPlayerName = "Blob Jr."
      $0.isLetsPlayButtonDisabled = false
    }
    await self.store.send(.letsPlayButtonTapped) {
      $0.isGameActive = true
    }
    await self.store.send(.gameDismissed) {
      $0.isGameActive = false
    }
    await self.store.send(.logoutButtonTapped)
  }
}
