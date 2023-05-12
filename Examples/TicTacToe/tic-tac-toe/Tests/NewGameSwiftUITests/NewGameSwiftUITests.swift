import ComposableArchitecture
import NewGameCore
import XCTest

@testable import NewGameSwiftUI

@MainActor
final class NewGameSwiftUITests: XCTestCase {
  let store = TestStore(initialState: NewGame.State()) {
    NewGame()
  } observe: {
    NewGameView.ViewState(state: $0)
  } send: {
    NewGame.Action(action: $0)
  }

  func testNewGame() async {
    await self.store.send(.xPlayerNameChanged("Blob Sr.")) {
      $0.xPlayerName = "Blob Sr."
    }
    await self.store.send(.oPlayerNameChanged("Blob Jr.")) {
      $0.oPlayerName = "Blob Jr."
      $0.isLetsPlayButtonDisabled = false
    }
  }
}
